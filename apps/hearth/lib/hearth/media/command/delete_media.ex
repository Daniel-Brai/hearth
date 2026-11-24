defmodule Hearth.Media.Command.DeleteMedia do
  alias Hearth.Media.Asset
  alias Hearth.Storage

  @spec execute(Asset.t()) :: {:ok, Asset.t()} | {:error, term()}
  def execute(%Asset{} = media) do
    if media.multipart_upload_id do
      Storage.abort_multipart(media.bucket_key, media.multipart_upload_id)
    end

    with :ok <- media |> Asset.prefix() |> Storage.delete_prefix(), do: Asset.delete(media)
  end
end
