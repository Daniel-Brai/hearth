defmodule Hearth.Media.Command.FailMedia do
  alias Hearth.Media
  alias Hearth.Media.Asset
  alias Hearth.Media.MediaFailed
  alias Hearth.Storage

  @spec execute(Asset.t(), String.t()) ::
          {:ok, Asset.t()} | {:error, :invalid_transition | :stale | term()}
  def execute(%Asset{} = media, failure) when is_binary(failure) do
    if media.multipart_upload_id do
      Storage.abort_multipart(media.bucket_key, media.multipart_upload_id)
    end

    prefix = Asset.prefix(media)

    with :ok <- Storage.delete_prefix(prefix),
         {:ok, media} <- Asset.advance(media, :fail, failure: failure, multipart_upload_id: nil) do
      Media.broadcast_to_pubsub(%MediaFailed{
        media_id: media.id,
        uploader_id: media.uploader_id,
        failure: failure
      })

      {:ok, media}
    end
  end
end
