defmodule Hearth.Media.Worker.ProcessImage do
  use Oban.Worker,
    queue: :media,
    max_attempts: 5,
    unique: [period: :infinity, keys: [:media_id], states: :incomplete]

  use Rop

  alias Hearth.Common
  alias Hearth.Media
  alias Hearth.Media.Asset
  alias Hearth.Media.Command.FailMedia
  alias Hearth.Media.FileType
  alias Hearth.Media.TempFile
  alias Hearth.Media.Variant
  alias Hearth.Storage
  alias Image.Blurhash
  alias Vix.Vips.Image, as: Vimage

  @widths [320, 640, 1280, 2048]
  @lossy ~w[image/jpeg image/webp image/avif]
  @max_pixels 50_000_000
  @square [:avatar, :logo]

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"media_id" => id}}) do
    case Asset.get(id: id, status: :processing) do
      nil -> :ok
      %Asset{} = media -> TempFile.run(&process(media, &1))
    end
  end

  defp process(media, path) do
    result =
      download(%{media: media, path: path}) >>>
        open() >>>
        ensure_pixels() >>>
        clean_original() >>>
        write_variants() >>>
        make_blurhash() >>>
        finish()

    case result do
      {:ok, _media} -> :ok
      {:error, {:cancel, failure, reason}} -> cancel(media, failure, reason)
      {:error, reason} -> {:error, reason}
    end
  end

  defp download(state) do
    case Storage.download(state.media.bucket_key, state.path) do
      :ok -> {:ok, state}
      {:error, :not_found} -> cancel_with("The file was lost before it was processed.", :missing)
      error -> error
    end
  end

  defp open(state) do
    case Image.open(state.path, access: :sequential, fail_on: :error) do
      {:ok, image} -> {:ok, Map.put(state, :image, image)}
      {:error, _reason} -> cancel_with("The file isn't an image that can be read.", :unreadable)
    end
  end

  # Every frame of an animation is decoded so each one counts
  defp ensure_pixels(%{media: media, image: image} = state) do
    frames =
      case Vimage.header_value(image, "n-pages") do
        {:ok, frames} when frames > 1 and media.content_type == "image/gif" -> frames
        _still -> 1
      end

    case Image.width(image) * Image.height(image) * frames <= @max_pixels do
      true -> {:ok, state}
      false -> cancel_with("The image is bigger than 50 megapixels.", :too_many_pixels)
    end
  end

  # The stored original is written again upright and without its metadata, so a download
  # never says where or with what a photo was taken. A colour profile is applied first,
  # since it goes with the rest
  defp clean_original(%{media: media, path: path} = state) do
    with {:ok, image} <- open_whole(media, path),
         {:ok, {upright, _flags}} <- Image.autorotate(image),
         {:ok, srgb} <- to_srgb(upright),
         {:ok, data} <- Image.write(srgb, :memory, clean_options(media)),
         :ok <- Storage.put(media.bucket_key, data, media.content_type) do
      sha256 = :sha256 |> :crypto.hash(data) |> Base.encode16(case: :lower)

      {:ok, Map.put(state, :cleaned, byte_size: byte_size(data), sha256: sha256)}
    end
  end

  defp open_whole(%Asset{content_type: "image/gif"}, path),
    do: Image.open(path, pages: :all, access: :random)

  defp open_whole(_media, path), do: Image.open(path, access: :random)

  defp to_srgb(image) do
    case Vimage.header_value(image, "icc-profile-data") do
      {:ok, _profile} -> Image.to_colorspace(image, :srgb, intent: :perceptual)
      _none -> {:ok, image}
    end
  end

  defp clean_options(%Asset{content_type: "image/" <> format = type}) do
    quality = if type in @lossy, do: [quality: 92], else: []

    [suffix: "." <> format, strip_metadata: true] ++ quality
  end

  defp write_variants(%{media: media} = state) do
    {width, height} = oriented_size(state.image)
    longest = if media.purpose in @square, do: min(width, height), else: width

    widths =
      case Enum.filter(@widths, &(&1 <= longest)) do
        [] -> [longest]
        widths -> widths
      end

    formats = if FileType.avif?(), do: [:webp, :avif], else: [:webp]

    results =
      Common.span("image.variants", %{count: length(widths) * length(formats)}, fn ->
        for width <- widths, format <- formats, do: write_variant(state, width, format)
      end)

    case Enum.find(results, &match?({:error, _reason}, &1)) do
      nil -> {:ok, Map.put(state, :variants, Enum.map(results, &elem(&1, 1)))}
      error -> error
    end
  end

  # Each size is made from the file itself so libvips can shrink while decoding
  defp write_variant(%{media: media, path: path}, width, format) do
    key = Asset.key(media, "w#{width}.#{format}")
    options = [suffix: ".#{format}", minimize_file_size: true, strip_metadata: true]

    with {:ok, resized} <- resize(media, path, width),
         {:ok, data} <- Image.write(resized, :memory, options),
         :ok <- Storage.put(key, data, "image/#{format}") do
      frames = max(Image.pages(resized), 1)

      variant = %Variant{
        width: Image.width(resized),
        height: div(Image.height(resized), frames),
        format: format,
        key: key
      }

      {:ok, {variant, data}}
    end
  end

  defp resize(%Asset{purpose: purpose}, path, width) when purpose in @square do
    Image.thumbnail(path, width, height: width, crop: :attention, resize: :down)
  end

  defp resize(%Asset{content_type: "image/gif"}, path, width) do
    with {:ok, frames} <- Image.open(path, pages: :all, access: :random) do
      Image.thumbnail(frames, width, resize: :down)
    end
  end

  defp resize(_media, path, width), do: Image.thumbnail(path, width, resize: :down)

  # The hash is made from the smallest size written, as the image was already streamed once
  defp make_blurhash(state) do
    {_variant, data} = Enum.min_by(state.variants, fn {variant, _data} -> variant.width end)

    with {:ok, image} <- Image.from_binary(data),
         {:ok, blurhash} <- Blurhash.encode(image) do
      {:ok, Map.put(state, :blurhash, blurhash)}
    end
  end

  defp finish(%{media: media} = state) do
    variants = Enum.map(state.variants, &elem(&1, 0))
    largest = Enum.max_by(variants, & &1.width)

    changes =
      [
        width: largest.width,
        height: largest.height,
        blurhash: state.blurhash,
        variants: variants
      ] ++ state.cleaned

    case Asset.advance(media, :processed, changes) do
      {:ok, media} ->
        Media.broadcast_ready(media)
        {:ok, media}

      # Moved on while this ran, such as being held or a duplicate run
      {:error, _moved_on} ->
        {:ok, media}
    end
  end

  # A photo taken with the phone on its side is stored sideways with an orientation that says so
  defp oriented_size(image) do
    {width, height} = {Image.width(image), Image.height(image)}

    case Vimage.header_value(image, "orientation") do
      {:ok, orientation} when orientation in 5..8 -> {height, width}
      _upright -> {width, height}
    end
  end

  defp cancel_with(failure, reason), do: {:error, {:cancel, failure, reason}}

  defp cancel(media, failure, reason) do
    _failed = FailMedia.execute(media, failure)
    {:cancel, reason}
  end
end
