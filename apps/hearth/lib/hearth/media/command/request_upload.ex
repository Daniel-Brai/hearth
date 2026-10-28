defmodule Hearth.Media.Command.RequestUpload do
  use Rop

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Common
  alias Hearth.Media.Asset
  alias Hearth.Media.FileType
  alias Hearth.Storage

  @max_unfinished 20
  @max_per_hour 60

  @spec execute(User.t(), map()) ::
          {:ok, Asset.t()} | {:error, :too_many_unfinished | :rate_limited | Changeset.t()}
  def execute(%User{id: uploader_id}, %{} = params) do
    key = params[:idempotency_key] || params["idempotency_key"]

    case existing(uploader_id, key) do
      %Asset{} = media ->
        {:ok, media}

      _new ->
        ensure_under_limits(uploader_id) >>>
          insert(key, params) >>>
          maybe_multipart()
    end
  end

  defp ensure_under_limits(uploader_id) do
    since = DateTime.add(DateTime.utc_now(), -1, :hour)

    case Asset.upload_counts(uploader_id, since) do
      %{unfinished: count} when count >= @max_unfinished -> {:error, :too_many_unfinished}
      %{recent: count} when count >= @max_per_hour -> {:error, :rate_limited}
      _counts -> {:ok, uploader_id}
    end
  end

  defp insert(uploader_id, key, params) do
    id = Common.new_id()
    media = %Asset{id: id, uploader_id: uploader_id, bucket_key: Asset.key(id, "original")}

    case Asset.insert(media, params) do
      {:ok, media} -> {:ok, media}
      {:error, changeset} -> retried(changeset, uploader_id, key)
    end
  end

  # When two requests with the same key arrive at once, the loser returns the row the other made
  defp retried(changeset, uploader_id, key) do
    taken? = Keyword.has_key?(changeset.errors, :uploader_id)

    with true <- taken?,
         %Asset{} = media <- existing(uploader_id, key) do
      {:ok, media}
    else
      _other -> {:error, changeset}
    end
  end

  defp maybe_multipart(%Asset{byte_size: size} = media) do
    case size > FileType.multipart_above() do
      true ->
        Storage.start_multipart(media.bucket_key, media.content_type) >>>
          then(&Asset.transition(media, :uploading, multipart_upload_id: &1))

      false ->
        {:ok, media}
    end
  end

  defp existing(uploader_id, key) when is_binary(key),
    do: Asset.get(uploader_id: uploader_id, idempotency_key: key)

  defp existing(_uploader_id, _key), do: nil
end
