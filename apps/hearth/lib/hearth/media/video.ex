defmodule Hearth.Media.Video do
  alias Hearth.Common

  @containers ~w[mov mp4 matroska webm]
  @kept_env ~w[PATH HOME LANG TMPDIR]
  @probe_timeout :timer.minutes(1)
  @convert_timeout :timer.minutes(60)

  # The shorter side becomes at most 1080 and -2 keeps the other side even for H.264
  @scale "scale='if(lte(iw,ih),min(iw,1080),-2)':'if(lte(iw,ih),-2,min(ih,1080))'"

  @type info :: %{
          duration_ms: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer(),
          video_codec: String.t(),
          audio_codec: nil | String.t()
        }

  @spec probe(Path.t()) :: {:ok, info()} | {:error, :not_a_video}
  def probe(path) do
    # Only the JSON and the exit status matter, so nothing is printed
    args = ["-v", "quiet", "-print_format", "json", "-show_streams", "-show_format", path]

    Common.span("ffprobe", %{}, fn ->
      case MuonTrap.cmd("ffprobe", args, timeout: @probe_timeout, env: clean_env()) do
        {json, 0} -> parse(json)
        {_output, _status} -> {:error, :not_a_video}
      end
    end)
  end

  @spec convert(Path.t(), Path.t(), info()) :: :ok | {:error, :not_converted}
  def convert(input, output, %{} = info) do
    codecs =
      case remux?(info) do
        true ->
          ~w[-c copy]

        false ->
          ~w[-c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -vf #{@scale}] ++
            ~w[-c:a aac -b:a 128k]
      end

    args =
      Enum.concat([
        ["-v", "error", "-y", "-i", input],
        ~w[-map 0:v:0 -map 0:a:0? -map_metadata -1 -map_chapters -1],
        codecs,
        ["-movflags", "+faststart", "-f", "mp4", output]
      ])

    run_ffmpeg(args)
  end

  # Copies the picture and sound as they are into the same kind of file, leaving out
  # metadata, chapters and data tracks, where a phone can keep where it was filmed
  @spec clean(Path.t(), Path.t(), String.t()) :: :ok | {:error, :not_converted}
  def clean(input, output, container) when container in @containers do
    run_ffmpeg(
      Enum.concat([
        ["-v", "error", "-y", "-i", input],
        ~w[-map 0:v -map 0:a? -map_metadata -1 -map_metadata:s -1 -map_chapters -1],
        ~w[-c copy -fflags +bitexact -f #{container}],
        [output]
      ])
    )
  end

  @spec poster(Path.t(), Path.t(), non_neg_integer()) :: :ok | {:error, :not_converted}
  def poster(video, output, duration_ms) do
    at = if duration_ms > 1_000, do: "1", else: "0"

    run_ffmpeg(["-v", "error", "-y", "-ss", at, "-i", video, "-frames:v", "1", output])
  end

  # Stretches quieter than -40 dB for half a second or more, in milliseconds
  # A silence still going at the end has no end
  @spec silences(Path.t()) ::
          {:ok, [{non_neg_integer(), nil | non_neg_integer()}]} | {:error, :not_converted}
  def silences(path) do
    args =
      ~w[-hide_banner -nostats -i] ++ [path] ++ ~w[-af silencedetect=noise=-40dB:d=0.5 -f null -]

    options = [timeout: @convert_timeout, stderr_to_stdout: true, env: clean_env()]

    Common.span("ffmpeg.silences", %{}, fn ->
      case MuonTrap.cmd("ffmpeg", args, options) do
        {output, 0} -> {:ok, parse_silences(output)}
        {_output, _status} -> {:error, :not_converted}
      end
    end)
  end

  defp parse_silences(output) do
    ~r/silence_(start|end): (-?[\d.]+)/
    |> Regex.scan(output, capture: :all_but_first)
    |> Enum.map(fn [edge, seconds] ->
      {value, _rest} = Float.parse(seconds)
      {edge, max(round(value * 1_000), 0)}
    end)
    |> pair_silences([])
  end

  defp pair_silences([{"start", from}, {"end", to} | rest], silences),
    do: pair_silences(rest, [{from, to} | silences])

  defp pair_silences([{"start", from}], silences), do: Enum.reverse([{from, nil} | silences])
  defp pair_silences([_unpaired | rest], silences), do: pair_silences(rest, silences)
  defp pair_silences([], silences), do: Enum.reverse(silences)

  @spec run_ffmpeg([String.t()]) :: :ok | {:error, :not_converted}
  def run_ffmpeg(args) do
    options = [timeout: @convert_timeout, stderr_to_stdout: true, env: clean_env()]

    # Named by what it writes, so a mix and a poster read apart in a trace
    Common.span("ffmpeg", %{output: args |> List.last() |> Path.basename()}, fn ->
      case MuonTrap.cmd("ffmpeg", args, options) do
        {_output, 0} -> :ok
        {_output, _status} -> {:error, :not_converted}
      end
    end)
  end

  # ffmpeg gets only what finding programs and temp files need, not the server's secrets
  defp clean_env do
    env = System.get_env()

    env
    |> Map.new(fn {name, _value} -> {name, nil} end)
    |> Map.merge(Map.take(env, @kept_env))
  end

  defp remux?(info) do
    info.video_codec == "h264" and info.audio_codec in [nil, "aac"] and
      min(info.width, info.height) <= 1080
  end

  # ffprobe also reads still images as one-frame videos so the container must be a video one
  defp parse(json) do
    with {:ok, %{"streams" => streams, "format" => format}} <- Jason.decode(json),
         true <- video_container?(format),
         %{} = video <- Enum.find(streams, &picture?/1) do
      audio = Enum.find(streams, &(&1["codec_type"] == "audio"))
      {width, height} = shown_size(video)

      {:ok,
       %{
         duration_ms: duration_ms(format),
         width: width,
         height: height,
         video_codec: video["codec_name"],
         audio_codec: get_in(audio["codec_name"])
       }}
    else
      _not_video -> {:error, :not_a_video}
    end
  end

  defp video_container?(%{"format_name" => names}) do
    names
    |> String.split(",")
    |> Enum.any?(&(&1 in @containers))
  end

  defp video_container?(_format), do: false

  # Cover art in an audio file is a video stream too
  defp picture?(stream) do
    stream["codec_type"] == "video" and get_in(stream, ~w[disposition attached_pic]) != 1
  end

  defp duration_ms(%{"duration" => duration}) do
    case Float.parse(duration) do
      {seconds, _rest} -> round(seconds * 1_000)
      :error -> 0
    end
  end

  defp duration_ms(_format), do: 0

  # A phone held upright records sideways and says how to turn it
  defp shown_size(%{"width" => width, "height" => height} = stream) do
    case rotation(stream) do
      quarter when quarter in [90, 270] -> {height, width}
      _upright -> {width, height}
    end
  end

  defp rotation(stream) do
    side_data = Enum.find_value(stream["side_data_list"] || [], & &1["rotation"])
    degrees = side_data || stream |> get_in(~w[tags rotate]) |> to_number()

    rem(abs(degrees), 360)
  end

  defp to_number(nil), do: 0

  defp to_number(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, _rest} -> number
      :error -> 0
    end
  end
end
