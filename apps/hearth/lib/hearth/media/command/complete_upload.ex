defmodule Hearth.Media.Command.CompleteUpload do
  use Rop

  alias Hearth.Media.Asset
  alias Hearth.Media.Command.FailMedia
  alias Hearth.Media.Document
  alias Hearth.Media.FileType
  alias Hearth.Media.TempFile
  alias Hearth.Media.Worker.ProcessImage
  alias Hearth.Media.Worker.ProcessVideo
  alias Hearth.Repo
  alias Hearth.Storage
  alias Hearth.Storage.Object

  @mismatch "The file isn't the size or type it was said to be."

  @spec execute(Asset.t(), [{pos_integer(), String.t()}]) ::
          {:ok, Asset.t()}
          | {:error, :not_uploaded | :mismatch | :content_mismatch | :failed | term()}
  def execute(%Asset{status: :uploading} = media, parts) when is_list(parts) do
    result =
      stored(media, parts) >>>
        ensure_promised(media) >>>
        ensure_content() >>>
        confirm(parts)

    case result do
      {:error, :mismatch} = error -> fail(media, @mismatch, error)
      {:error, :content_mismatch} = error -> fail(media, content_message(), error)
      result -> result
    end
  end

  def execute(%Asset{status: :failed}, _parts), do: {:error, :failed}
  def execute(%Asset{} = media, _parts), do: {:ok, media}

  defp stored(%Asset{multipart_upload_id: nil} = media, _parts), do: head(media)

  defp stored(%Asset{} = media, parts) do
    case head(media) do
      {:ok, object} -> {:ok, object}
      {:error, :not_uploaded} -> complete_multipart(media, parts)
    end
  end

  defp complete_multipart(media, parts) do
    case Storage.complete_multipart(media.bucket_key, media.multipart_upload_id, parts) do
      :ok -> head(media)
      error -> error
    end
  end

  defp head(media) do
    case Storage.head(media.bucket_key) do
      {:ok, object} -> {:ok, object}
      {:error, :not_found} -> {:error, :not_uploaded}
      error -> error
    end
  end

  defp ensure_promised(%Object{} = object, %Asset{} = media) do
    case object.size == media.byte_size and object.content_type == media.content_type do
      true -> {:ok, media}
      false -> {:error, :mismatch}
    end
  end

  defp ensure_content(%Asset{content_type: type} = media) do
    case FileType.kind(type) do
      :document -> TempFile.run(&check_document(media, &1))
      _media -> {:ok, media}
    end
  end

  defp check_document(media, path) do
    with :ok <- Storage.download(media.bucket_key, path),
         :ok <- Document.check(path, media.content_type) do
      {:ok, media}
    end
  end

  defp confirm(media, parts) do
    result =
      Repo.transact(fn ->
        Asset.advance(media, :confirm, multipart_upload_id: nil) >>>
          queue_processing()
      end)

    # Someone else moved it first, such as a second confirm at the same time
    case result do
      {:error, :stale} -> execute(Asset.get(id: media.id), parts)
      result -> result
    end
  end

  defp queue_processing(%Asset{status: :processing} = media) do
    worker =
      case FileType.kind(media.content_type) do
        :image -> ProcessImage
        :video -> ProcessVideo
      end

    %{media_id: media.id}
    |> worker.new()
    |> Oban.insert!()

    {:ok, media}
  end

  defp queue_processing(media), do: {:ok, media}

  defp fail(media, failure, error) do
    _failed = FailMedia.execute(media, failure)
    error
  end

  defp content_message do
    "The file's contents don't match its type. Allowed documents: #{FileType.document_names()}."
  end
end
