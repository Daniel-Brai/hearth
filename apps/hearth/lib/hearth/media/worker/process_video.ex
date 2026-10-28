defmodule Hearth.Media.Worker.ProcessVideo do
  use Oban.Worker,
    queue: :video,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:media_id], states: :incomplete]

  use Rop

  alias Hearth.Media
  alias Hearth.Media.Asset
  alias Hearth.Media.Command.FailMedia
  alias Hearth.Media.FileType
  alias Hearth.Media.TempFile
  alias Hearth.Media.Variant
  alias Hearth.Media.Video
  alias Hearth.Storage
  alias Image.Blurhash

  @max_long_side 3_840
  @max_short_side 2_160
  @poster_width 1_280

  @containers %{
    "video/mp4" => "mp4",
    "video/quicktime" => "mov",
    "video/webm" => "webm",
    "video/x-matroska" => "matroska"
  }

  @impl Oban.Worker
  def timeout(%Oban.Job{}), do: :timer.minutes(90)

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_id" => id}}) do
    case Asset.get(id: id, status: :processing) do
      nil -> :ok
      %Asset{} = media -> TempFile.run(&process(media, &1))
    end
  end

  # dir comes from TempFile.run/1, made from a new id
  # sobelow_skip ["Traversal.FileModule"]
  defp process(media, dir) do
    File.mkdir_p!(dir)

    result =
      download(%{media: media, dir: dir, original: Path.join(dir, "original")}) >>>
        probe() >>>
        ensure_allowed() >>>
        clean_original() >>>
        convert() >>>
        make_poster() >>>
        store() >>>
        finish()

    case result do
      {:ok, _media} -> :ok
      {:error, {:cancel, failure, reason}} -> cancel(media, failure, reason)
      {:error, reason} -> {:error, reason}
    end
  end

  defp download(state) do
    case Storage.download(state.media.bucket_key, state.original) do
      :ok -> {:ok, state}
      {:error, :not_found} -> cancel_with("The file was lost before it was processed.", :missing)
      error -> error
    end
  end

  defp probe(state) do
    case Video.probe(state.original) do
      {:ok, info} ->
        {:ok, Map.put(state, :info, info)}

      {:error, :not_a_video} ->
        cancel_with("The file isn't a video that can be played.", :unreadable)
    end
  end

  defp ensure_allowed(%{info: info} = state) do
    minutes = div(FileType.max_video_ms(), 60_000)
    long = max(info.width, info.height)
    short = min(info.width, info.height)

    cond do
      info.duration_ms > FileType.max_video_ms() ->
        cancel_with("The video is longer than #{minutes} minutes.", :too_long)

      long > @max_long_side or short > @max_short_side ->
        cancel_with("The video is bigger than 4K.", :too_big)

      true ->
        {:ok, state}
    end
  end

  # The stored original is replaced by the same video without its metadata, so a download
  # never says where or on what it was filmed. It fails closed rather than keep it
  defp clean_original(%{media: media} = state) do
    clean = Path.join(state.dir, "clean")

    with :ok <- Video.clean(state.original, clean, Map.fetch!(@containers, media.content_type)),
         :ok <- Storage.upload_file(media.bucket_key, clean, media.content_type) do
      {:ok, Map.merge(state, %{original: clean, cleaned: file_facts(clean)})}
    else
      {:error, :not_converted} -> cancel_with("The video couldn't be converted.", :not_converted)
      error -> error
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp file_facts(path) do
    sha256 =
      path
      |> File.stream!(65_536)
      |> Enum.reduce(:crypto.hash_init(:sha256), &:crypto.hash_update(&2, &1))
      |> :crypto.hash_final()
      |> Base.encode16(case: :lower)

    [byte_size: File.stat!(path).size, sha256: sha256]
  end

  defp convert(state) do
    output = Path.join(state.dir, "video.mp4")

    with :ok <- Video.convert(state.original, output, state.info),
         {:ok, converted} <- Video.probe(output) do
      {:ok, Map.merge(state, %{output: output, converted: converted})}
    else
      _failed -> cancel_with("The video couldn't be converted.", :not_converted)
    end
  end

  defp make_poster(state) do
    frame = Path.join(state.dir, "poster.png")

    with :ok <- Video.poster(state.output, frame, state.converted.duration_ms),
         {:ok, image} <- Image.thumbnail(frame, @poster_width, resize: :down),
         {:ok, data} <- Image.write(image, :memory, suffix: ".webp", strip_metadata: true),
         {:ok, preview} <- Image.from_binary(data),
         {:ok, blurhash} <- Blurhash.encode(preview) do
      poster = %{data: data, width: Image.width(image), height: Image.height(image)}

      {:ok, Map.merge(state, %{poster: poster, blurhash: blurhash})}
    else
      _failed -> cancel_with("The video's first frame couldn't be read.", :no_poster)
    end
  end

  defp store(%{media: media, poster: poster, converted: converted} = state) do
    video_key = Asset.key(media, "video.mp4")
    poster_key = Asset.key(media, "poster.webp")

    with :ok <- Storage.upload_file(video_key, state.output, "video/mp4"),
         :ok <- Storage.put(poster_key, poster.data, "image/webp") do
      variants = [
        %Variant{width: converted.width, height: converted.height, format: :mp4, key: video_key},
        %Variant{width: poster.width, height: poster.height, format: :webp, key: poster_key}
      ]

      {:ok, Map.put(state, :variants, variants)}
    end
  end

  defp finish(%{media: media, converted: converted} = state) do
    changes =
      [
        width: converted.width,
        height: converted.height,
        duration_ms: converted.duration_ms,
        blurhash: state.blurhash,
        variants: state.variants
      ] ++ state.cleaned

    case Asset.advance(media, :processed, changes) do
      {:ok, media} ->
        Media.broadcast_ready(media)
        {:ok, media}

      # Moved on while this ran, such as a duplicate run that finished first
      {:error, _moved_on} ->
        {:ok, media}
    end
  end

  defp cancel_with(failure, reason), do: {:error, {:cancel, failure, reason}}

  defp cancel(media, failure, reason) do
    _failed = FailMedia.execute(media, failure)
    {:cancel, reason}
  end
end
