defmodule Hearth.Voice.Worker.AssembleRecording do
  use Oban.Worker,
    queue: :video,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:recording_id], states: :incomplete]

  use Rop

  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.Media.TempFile
  alias Hearth.Media.Video
  alias Hearth.Repo
  alias Hearth.Storage
  alias Hearth.TranscriptionPolicy
  alias Hearth.Voice
  alias Hearth.Voice.Command.FailRecording
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Recording.Speaker
  alias Hearth.Voice.Slate
  alias Hearth.Voice.TrackFile

  require Logger

  # How long the raw tracks may take to arrive after the stop
  @upload_wait_ms :timer.minutes(10)
  @poster_width 1_280

  @spec job(T.id()) :: Ecto.Changeset.t()
  def job(recording_id), do: new(%{recording_id: recording_id})

  @impl Oban.Worker
  def timeout(%Oban.Job{}), do: :timer.minutes(120)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"recording_id" => id}}) do
    case Recording.get(id: id, status: :processing) do
      nil -> :ok
      %Recording{tracks: []} = recording -> wait_for_tracks(recording)
      %Recording{} = recording -> TempFile.run(&assemble(recording, &1))
    end
  end

  defp wait_for_tracks(recording) do
    waited = DateTime.diff(DateTime.utc_now(), recording.ended_at, :millisecond)

    case waited > @upload_wait_ms do
      true ->
        _failed = FailRecording.execute(recording, "The recording's files were lost.")
        {:cancel, :no_tracks}

      false ->
        {:snooze, 5}
    end
  end

  # dir comes from TempFile.run/1, made from a new id
  # sobelow_skip ["Traversal.FileModule"]
  defp assemble(recording, dir) do
    File.mkdir_p!(dir)
    started = System.monotonic_time(:millisecond)

    result =
      download(%{recording: recording, dir: dir, started: started}) >>>
        convert() >>>
        draw_slate() >>>
        mix() >>>
        split_speakers() >>>
        make_poster() >>>
        store() >>>
        finish()

    case result do
      {:ok, _recording} ->
        :ok

      {:error, {:cancel, failure, reason}} ->
        _failed = FailRecording.execute(recording, failure)
        {:cancel, reason}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp download(%{recording: recording, dir: dir} = state) do
    tracks =
      recording.tracks
      |> Enum.with_index()
      |> Enum.map(fn {track, n} -> {track, Path.join(dir, "#{n}.rtp")} end)

    Enum.reduce_while(tracks, {:ok, Map.put(state, :raw, tracks)}, fn {track, path}, ok ->
      case Storage.download(track.key, path) do
        :ok -> {:cont, ok}
        {:error, :not_found} -> {:halt, cancel_with("The recording's files were lost.", :missing)}
        error -> {:halt, error}
      end
    end)
  end

  defp convert(state) do
    inputs =
      Common.span("recording.convert_tracks", %{tracks: length(state.raw)}, fn ->
        Enum.flat_map(state.raw, &converted/1)
      end)

    case Enum.filter(inputs, &(&1.track.kind == :audio)) do
      [] -> cancel_with("Nobody spoke while it was recording.", :silent)
      audio -> {:ok, Map.merge(state, %{audio: audio, video: inputs -- audio})}
    end
  end

  defp converted({track, raw}) do
    case convert_track(track, raw) do
      {:ok, path, converted} -> [Map.merge(converted, %{track: track, path: path})]
      {:error, _empty} -> []
    end
  end

  defp convert_track(%{kind: :audio}, raw) do
    path = Path.rootname(raw) <> ".ogg"
    with {:ok, converted} <- TrackFile.to_ogg(raw, path), do: {:ok, path, converted}
  end

  defp convert_track(%{kind: :video}, raw) do
    path = Path.rootname(raw) <> ".ivf"
    with {:ok, converted} <- TrackFile.to_ivf(raw, path), do: {:ok, path, converted}
  end

  defp draw_slate(%{recording: recording} = state) do
    slate = Path.join(state.dir, "slate.png")
    room = room_name(recording)

    case Slate.write(slate, room.name, room.community) do
      :ok -> {:ok, Map.put(state, :slate, slate)}
      {:error, _reason} -> cancel_with("The recording's picture couldn't be drawn.", :no_slate)
    end
  end

  defp room_name(recording) do
    with {:ok, room} <- Communities.get_room(id: recording.room_id),
         {:ok, community} <- Communities.get_community(id: recording.community_id) do
      %{name: room.name, community: community.name}
    else
      _gone -> %{name: "Voice room", community: ""}
    end
  end

  defp mix(%{recording: recording} = state) do
    output = Path.join(state.dir, "video.mp4")
    duration_ms = DateTime.diff(recording.ended_at, recording.started_at, :millisecond)
    seconds = seconds(max(duration_ms, 1_000))
    {width, height} = Slate.size()

    inputs =
      [["-loop", "1", "-framerate", "30", "-t", seconds, "-i", state.slate]] ++
        Enum.map(state.audio, &["-i", &1.path]) ++
        Enum.map(state.video, &["-i", &1.path])

    filter =
      Enum.join(video_filter(state, width, height) ++ audio_filter(state.audio, 1, seconds), ";")

    args =
      Enum.concat([
        ["-v", "error", "-y"],
        List.flatten(inputs),
        ["-filter_complex", filter, "-map", "[vout]", "-map", "[aout]"],
        ~w[-c:v libx264 -preset veryfast -crf 23 -pix_fmt yuv420p -r 30],
        ~w[-c:a aac -b:a 128k -ar 48000],
        ["-t", seconds, "-movflags", "+faststart", "-f", "mp4", output]
      ])

    with :ok <- Video.run_ffmpeg(args),
         {:ok, info} <- Video.probe(output) do
      {:ok, Map.merge(state, %{output: output, info: info})}
    else
      _failed -> cancel_with("The recording couldn't be put together.", :not_mixed)
    end
  end

  # Input 0 is the slate then the audio then the shares
  # Each share is fitted into the frame from when it started
  defp video_filter(state, width, height) do
    first_share = 1 + length(state.audio)
    base = "[0:v]scale=#{width}:#{height},format=yuv420p,setsar=1[base0]"

    shares =
      state.video
      |> Enum.with_index()
      |> Enum.flat_map(fn {share, n} ->
        input = first_share + n
        from = seconds(share.offset_ms)
        to = seconds(share.offset_ms + share.track.duration_ms)

        [
          "[#{input}:v]scale=#{width}:#{height}:force_original_aspect_ratio=decrease," <>
            "pad=#{width}:#{height}:(ow-iw)/2:(oh-ih)/2,setsar=1,format=yuv420p," <>
            "setpts=PTS-STARTPTS+#{from}/TB[share#{n}]",
          "[base#{n}][share#{n}]overlay=eof_action=pass:enable='between(t,#{from},#{to})'" <>
            "[base#{n + 1}]"
        ]
      end)

    last = "[base#{length(state.video)}]null[vout]"
    [base | shares] ++ [last]
  end

  # Each stretch of speech is delayed to when it was said, then all are
  # mixed at their own level. The mix is padded with silence to the
  # recording's length and cut there, so every stream in the graph ends on
  # its own. An endless apad left to the output's -t sometimes spun forever
  defp audio_filter(audio, first_input, seconds) do
    delayed =
      audio
      |> Enum.with_index()
      |> Enum.map(fn {stretch, n} ->
        ms = stretch.offset_ms

        "[#{first_input + n}:a]aresample=48000,aformat=channel_layouts=stereo," <>
          "adelay=#{ms}|#{ms}[a#{n}]"
      end)

    labels = Enum.map_join(0..(length(audio) - 1), &"[a#{&1}]")

    mix =
      "#{labels}amix=inputs=#{length(audio)}:normalize=0:dropout_transition=0," <>
        "apad=whole_dur=#{seconds},atrim=duration=#{seconds}[aout]"

    Enum.reverse([mix | Enum.reverse(delayed)])
  end

  defp split_speakers(%{audio: audio} = state) do
    seconds = seconds(state.info.duration_ms)

    speakers =
      audio
      |> Enum.group_by(& &1.track.user_id)
      |> Enum.map(fn {user_id, stretches} ->
        path = Path.join(state.dir, "speaker-#{user_id}.m4a")
        inputs = Enum.flat_map(stretches, &["-i", &1.path])
        filter = stretches |> audio_filter(0, seconds) |> Enum.join(";")

        args =
          ~w[-v error -y] ++
            inputs ++
            ["-filter_complex", filter, "-map", "[aout]"] ++
            ~w[-ac 1 -c:a aac -b:a 64k] ++ ["-t", seconds, "-movflags", "+faststart", path]

        {user_id, path, Video.run_ffmpeg(args)}
      end)

    case Enum.all?(speakers, &match?({_user, _path, :ok}, &1)) do
      true -> {:ok, Map.put(state, :speakers, Enum.map(speakers, fn {u, p, :ok} -> {u, p} end))}
      false -> cancel_with("A speaker's audio couldn't be saved.", :no_speakers)
    end
  end

  defp make_poster(state) do
    frame = Path.join(state.dir, "poster.png")

    with :ok <- Video.poster(state.output, frame, state.info.duration_ms),
         {:ok, image} <- Image.thumbnail(frame, @poster_width, resize: :down),
         {:ok, data} <- Image.write(image, :memory, suffix: ".webp", strip_metadata: true) do
      {:ok, Map.put(state, :poster, data)}
    else
      _failed -> cancel_with("The recording's poster couldn't be made.", :no_poster)
    end
  end

  defp store(%{recording: recording} = state) do
    video_key = Recording.key(recording, "video.mp4")
    poster_key = Recording.key(recording, "poster.webp")

    speakers =
      Enum.map(state.speakers, fn {user_id, path} ->
        {%Speaker{user_id: user_id, key: Recording.key(recording, "speakers/#{user_id}.m4a")},
         path}
      end)

    with :ok <- Storage.upload_file(video_key, state.output, "video/mp4"),
         :ok <- Storage.put(poster_key, state.poster, "image/webp"),
         :ok <- upload_speakers(speakers) do
      {:ok,
       Map.merge(state, %{
         video_key: video_key,
         poster_key: poster_key,
         speaker_rows: Enum.map(speakers, &elem(&1, 0))
       })}
    end
  end

  defp upload_speakers(speakers) do
    Enum.reduce_while(speakers, :ok, fn {speaker, path}, :ok ->
      case Storage.upload_file(speaker.key, path, "audio/mp4") do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp finish(%{recording: recording, info: info} = state) do
    processing_ms = System.monotonic_time(:millisecond) - state.started
    %{size: byte_size} = File.stat!(state.output)

    changes = [
      video_key: state.video_key,
      poster_key: state.poster_key,
      speakers: state.speaker_rows,
      duration_ms: info.duration_ms,
      byte_size: byte_size,
      width: info.width,
      height: info.height,
      processing_ms: processing_ms
    ]

    case finish_and_queue(recording, changes) do
      {:ok, ready} ->
        for track <- recording.tracks, do: Storage.delete(track.key)
        Voice.broadcast_recording(ready)
        log_speed(ready)
        {:ok, ready}

      # Moved on while this ran, such as a duplicate run that finished first
      {:error, _moved_on} ->
        {:ok, recording}
    end
  end

  # The transcript job goes in with the status so a crash can't leave a ready recording untranscribed
  defp finish_and_queue(recording, changes) do
    Repo.transact(fn ->
      with {:ok, ready} <- Recording.advance(recording, :finish, changes),
           :ok <- TranscriptionPolicy.enqueue(ready.id) do
        {:ok, ready}
      end
    end)
  end

  defp log_speed(recording) do
    minutes = max(recording.duration_ms, 1) / 60_000
    per_minute = Float.round(recording.processing_ms / 1_000 / minutes, 1)

    Logger.info(
      "Voice recording #{recording.id} made in #{recording.processing_ms} ms, " <>
        "#{per_minute} s per minute recorded"
    )
  end

  defp seconds(ms), do: :erlang.float_to_binary(ms / 1_000, decimals: 3)

  defp cancel_with(failure, reason), do: {:error, {:cancel, failure, reason}}
end
