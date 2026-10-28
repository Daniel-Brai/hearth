defmodule Hearth.Media.Command.RenderShareCard do
  alias Hearth.Media.Asset
  alias Hearth.Media.ShareCard
  alias Hearth.Media.TempFile
  alias Hearth.Storage
  alias Vix.Vips.Image, as: Vips

  require Logger

  @spec execute(ShareCard.t()) :: {:ok, String.t()} | {:error, term()}
  def execute(%ShareCard{} = card) do
    key = "cards/#{ShareCard.fingerprint(card)}.jpg"

    case Storage.head(key) do
      {:ok, _object} -> {:ok, key}
      {:error, _missing} -> TempFile.run(&draw(card, key, &1))
    end
  end

  # dir comes from TempFile.run/1, made from a new id
  # sobelow_skip ["Traversal.FileModule"]
  defp draw(card, key, dir) do
    File.mkdir_p!(dir)

    with {:ok, jpeg} <- ShareCard.draw(card, &open(&1, dir)),
         :ok <- Storage.put(key, jpeg, "image/jpeg") do
      {:ok, key}
    end
  end

  # A picture that can't be read leaves the card without it rather than failing
  defp open(%Asset{status: :ready} = asset, dir) do
    key =
      case Enum.max_by(asset.variants, & &1.width, fn -> nil end) do
        nil -> asset.bucket_key
        variant -> variant.key
      end

    path = Path.join(dir, Path.basename(key))

    with :ok <- Storage.download(key, path),
         {:ok, image} <- Image.open(path),
         {:ok, image} <- Vips.copy_memory(image) do
      image
    else
      error ->
        Logger.warning("Share card drawn without #{asset.id}: #{inspect(error)}")
        nil
    end
  end

  defp open(%Asset{}, _dir), do: nil
end
