defmodule Hearth.Voice.TrackFile do
  alias ExWebRTC.Media.IVF
  alias ExWebRTC.Media.Ogg
  alias ExWebRTC.Media.Opus
  alias ExWebRTC.RTP.Depayloader
  alias ExWebRTC.RTPCodecParameters
  alias Hearth.RTC.Recorder

  @wrap 4_294_967_296
  @half 2_147_483_648

  # One 20 ms frame of silence, as the Opus spec defines it
  @silence <<0xF8, 0xFF, 0xFE>>
  @silence_samples 960

  @type converted :: %{
          offset_ms: non_neg_integer(),
          width: nil | pos_integer(),
          height: nil | pos_integer()
        }

  @spec to_ogg(Path.t(), Path.t()) :: {:ok, converted()} | {:error, :empty}
  def to_ogg(raw, path) do
    {:ok, writer} = Ogg.Writer.open(path, sample_rate: 48_000, channel_count: 2)
    start = %{writer: writer, next: nil, first_at: nil}

    done = Recorder.reduce(raw, start, fn at, packet, acc -> add_audio(acc, at, packet) end)
    :ok = Ogg.Writer.close(done.writer)

    case done.first_at do
      nil -> {:error, :empty}
      at -> {:ok, %{offset_ms: at, width: nil, height: nil}}
    end
  end

  # A stretch of speech held in memory, for a live caption
  @spec write_ogg([ExRTP.Packet.t()], Path.t()) :: :ok | {:error, :empty}
  def write_ogg(packets, path) when is_list(packets) do
    {:ok, writer} = Ogg.Writer.open(path, sample_rate: 48_000, channel_count: 2)
    start = %{writer: writer, next: nil, first_at: nil}

    done = Enum.reduce(packets, start, &add_audio(&2, 0, &1))
    :ok = Ogg.Writer.close(done.writer)

    if done.first_at, do: :ok, else: {:error, :empty}
  end

  defp add_audio(acc, _at, %{payload: <<>>}), do: acc

  defp add_audio(acc, at, packet) do
    with {:ok, duration} <- Opus.duration(packet.payload),
         {:ok, acc} <- fill(acc, packet.timestamp),
         {:ok, writer} <- Ogg.Writer.write_packet(acc.writer, packet.payload) do
      next = rem(packet.timestamp + duration * 48, @wrap)
      %{acc | writer: writer, next: next, first_at: acc.first_at || at}
    else
      _late_or_unreadable -> acc
    end
  end

  defp fill(%{next: nil} = acc, _timestamp), do: {:ok, acc}

  defp fill(acc, timestamp) do
    case rem(timestamp - acc.next + @wrap, @wrap) do
      late when late >= @half ->
        {:error, :late}

      gap ->
        frames = div(gap, @silence_samples)

        writer =
          Enum.reduce(1..frames//1, acc.writer, fn _n, writer ->
            {:ok, writer} = Ogg.Writer.write_packet(writer, @silence)
            writer
          end)

        {:ok, %{acc | writer: writer}}
    end
  end

  @spec to_ivf(Path.t(), Path.t()) :: {:ok, converted()} | {:error, :empty | term()}
  def to_ivf(raw, path) do
    codec = %RTPCodecParameters{payload_type: 96, mime_type: "video/VP8", clock_rate: 90_000}
    {:ok, depayloader} = Depayloader.new(codec)
    start = %{depayloader: depayloader, writer: nil, path: path, first: nil, last_ms: -1}

    done = Recorder.reduce(raw, start, fn at, packet, acc -> add_video(acc, at, packet) end)

    case done do
      %{writer: nil} ->
        {:error, :empty}

      %{writer: writer, first: first} ->
        :ok = IVF.Writer.close(writer)
        {:ok, %{offset_ms: first.at, width: first.width, height: first.height}}
    end
  end

  defp add_video(acc, at, packet) do
    case Depayloader.depayload(acc.depayloader, packet) do
      {nil, depayloader} -> %{acc | depayloader: depayloader}
      {frame, depayloader} -> write_frame(%{acc | depayloader: depayloader}, at, packet, frame)
    end
  end

  # Frames before the first keyframe can't be decoded so they are dropped
  defp write_frame(%{writer: nil} = acc, at, packet, frame) do
    case keyframe_size(frame) do
      {width, height} ->
        {:ok, writer} =
          IVF.Writer.open(acc.path,
            fourcc: :binary.decode_unsigned("VP80", :little),
            height: height,
            width: width,
            num_frames: 900,
            timebase_denum: 1_000,
            timebase_num: 1
          )

        first = %{at: at, timestamp: packet.timestamp, width: width, height: height}
        write_frame(%{acc | writer: writer, first: first}, at, packet, frame)

      nil ->
        acc
    end
  end

  defp write_frame(acc, _at, packet, frame) do
    elapsed = rem(packet.timestamp - acc.first.timestamp + @wrap, @wrap)
    ms = max(div(elapsed, 90), acc.last_ms + 1)
    {:ok, writer} = IVF.Writer.write_frame(acc.writer, %IVF.Frame{timestamp: ms, data: frame})

    %{acc | writer: writer, last_ms: ms}
  end

  defp keyframe_size(
         <<tag, _tag::binary-size(2), 0x9D, 0x01, 0x2A, width::little-16, height::little-16,
           _rest::binary>>
       )
       when Bitwise.band(tag, 1) == 0 do
    {Bitwise.band(width, 0x3FFF), Bitwise.band(height, 0x3FFF)}
  end

  defp keyframe_size(_frame), do: nil
end
