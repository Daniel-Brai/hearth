defmodule Hearth.Media do
  events = [MediaFailed, MediaReady]

  default = [Asset, Attachment, TempFile, Variant, Video | events]

  exports =
    case Mix.env() do
      :test -> [Document | default]
      _env -> default
    end

  use Rop

  use Boundary,
    deps: [Hearth.Accounts, Hearth.Common, Hearth.PubSub, Hearth.Repo, Hearth.Storage],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Common
  alias Hearth.Media.Asset
  alias Hearth.Media.Attachment
  alias Hearth.Media.Command.CompleteUpload
  alias Hearth.Media.Command.DeleteMedia
  alias Hearth.Media.Command.PutAttachments
  alias Hearth.Media.Command.RenderShareCard
  alias Hearth.Media.Command.RequestUpload
  alias Hearth.Media.FileType
  alias Hearth.Media.MediaReady
  alias Hearth.Media.ShareCard
  alias Hearth.Media.TempFile
  alias Hearth.PubSub
  alias Hearth.Storage

  @topic "media"

  @type upload ::
          %{url: String.t(), headers: %{String.t() => String.t()}}
          | %{upload_id: String.t(), part_size: pos_integer(), parts: pos_integer()}

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec broadcast_to_pubsub(struct()) :: :ok
  def broadcast_to_pubsub(event), do: PubSub.broadcast(@topic, event)

  @spec broadcast_ready(Asset.t()) :: :ok
  def broadcast_ready(%Asset{} = media) do
    broadcast_to_pubsub(%MediaReady{media_id: media.id, uploader_id: media.uploader_id})
  end

  @spec limits() :: map()
  def limits, do: FileType.limits()

  @spec get_media(Common.T.id()) :: {:ok, Asset.t()} | {:error, :not_found}
  def get_media(id) do
    with true <- Common.valid_id?(id),
         %Asset{} = media <- Asset.get(id: id) do
      {:ok, media}
    else
      _missing -> {:error, :not_found}
    end
  end

  # Someone else's file is :not_found, same as one that doesn't exist
  @spec fetch_own_media(User.t(), Common.T.id()) :: {:ok, Asset.t()} | {:error, :not_found}
  def fetch_own_media(%User{id: user_id}, id) do
    case get_media(id) do
      {:ok, %Asset{uploader_id: ^user_id} = media} -> {:ok, media}
      _missing -> {:error, :not_found}
    end
  end

  @spec request_upload(User.t(), map()) ::
          {:ok, %{media: Asset.t(), upload: nil | upload()}}
          | {:error, :too_many_unfinished | :rate_limited | Changeset.t() | term()}
  def request_upload(%User{} = user, %{} = params) do
    RequestUpload.execute(user, params) >>>
      with_upload()
  end

  @spec part_urls(User.t(), Asset.t(), [pos_integer()]) ::
          {:ok, %{pos_integer() => String.t()}}
          | {:error, :forbidden | :not_multipart | :invalid_part}
  def part_urls(%User{id: id}, %Asset{uploader_id: id} = media, numbers) when is_list(numbers) do
    parts = ceil(media.byte_size / Storage.part_size())

    case media do
      %Asset{status: :uploading, multipart_upload_id: nil} ->
        {:error, :not_multipart}

      %Asset{status: :uploading} ->
        case Enum.all?(numbers, &(&1 in 1..parts//1)) do
          true -> {:ok, Map.new(numbers, &{&1, part_url(media, &1)})}
          false -> {:error, :invalid_part}
        end

      %Asset{} ->
        {:error, :not_multipart}
    end
  end

  def part_urls(%User{}, %Asset{}, _numbers), do: {:error, :forbidden}

  @spec list_parts(User.t(), Asset.t()) ::
          {:ok, [Storage.Adapter.part()]} | {:error, :forbidden | :not_multipart | term()}
  def list_parts(%User{id: id}, %Asset{uploader_id: id} = media) do
    case media do
      %Asset{status: :uploading, multipart_upload_id: upload_id} when is_binary(upload_id) ->
        Storage.list_parts(media.bucket_key, upload_id)

      %Asset{} ->
        {:error, :not_multipart}
    end
  end

  def list_parts(%User{}, %Asset{}), do: {:error, :forbidden}

  @spec complete_upload(User.t(), Asset.t(), [{pos_integer(), String.t()}]) ::
          {:ok, Asset.t()}
          | {:error,
             :forbidden | :not_uploaded | :mismatch | :content_mismatch | :failed | term()}
  def complete_upload(user, media, parts \\ [])

  def complete_upload(%User{id: id}, %Asset{uploader_id: id, status: status} = media, parts) do
    with {:ok, completed} <- CompleteUpload.execute(media, parts) do
      if status == :uploading and completed.status == :ready, do: broadcast_ready(completed)

      {:ok, completed}
    end
  end

  def complete_upload(%User{}, %Asset{}, _parts), do: {:error, :forbidden}

  @spec urls(Asset.t()) ::
          nil
          | %{
              original: String.t(),
              download: String.t(),
              variants: [
                %{width: pos_integer(), height: pos_integer(), format: atom(), url: String.t()}
              ]
            }
  def urls(%Asset{status: :ready} = media) do
    {:ok, original} = Storage.get_url(media.bucket_key)

    variants =
      for variant <- media.variants do
        {:ok, url} = Storage.get_url(variant.key)
        %{width: variant.width, height: variant.height, format: variant.format, url: url}
      end

    {:ok, download} = Storage.download_url(media.bucket_key, media.name)

    %{original: original, download: download, variants: variants}
  end

  def urls(%Asset{}), do: nil

  @spec share_card_url(map()) :: {:ok, String.t()} | {:error, term()}
  def share_card_url(%{title: _title} = card) do
    card = struct!(ShareCard, card)

    with {:ok, key} <- RenderShareCard.execute(card), do: Storage.get_url(key)
  end

  @spec get_images([nil | Common.T.id()]) :: %{Common.T.id() => Asset.t()}
  def get_images(ids) when is_list(ids) do
    ids = ids |> Enum.reject(&is_nil/1) |> Enum.uniq()

    [id: ids, status: :ready]
    |> Asset.all()
    |> Map.new(&{&1.id, &1})
  end

  @spec avatar?(User.t(), Common.T.id()) :: boolean()
  def avatar?(%User{} = user, id) do
    case fetch_own_media(user, id) do
      {:ok, %Asset{purpose: :avatar, status: status}} -> status in [:processing, :ready]
      _other -> false
    end
  end

  @spec avatar_urls([nil | Common.T.id()]) :: %{Common.T.id() => String.t()}
  def avatar_urls(ids) when is_list(ids), do: image_urls(ids, 0)

  @spec image_urls([nil | Common.T.id()], non_neg_integer()) :: %{Common.T.id() => String.t()}
  def image_urls(ids, width) when is_list(ids) and is_integer(width) do
    ids = ids |> Enum.reject(&is_nil/1) |> Enum.uniq()

    for media <- Asset.all(id: ids, status: :ready),
        variant = fit(media.variants, width),
        variant != nil,
        {:ok, url} = Storage.get_url(variant.key),
        into: %{},
        do: {media.id, url}
  end

  defp fit(variants, width) do
    case Enum.filter(variants, &(&1.width >= width)) do
      [] -> Enum.max_by(variants, & &1.width, fn -> nil end)
      wide -> Enum.min_by(wide, & &1.width)
    end
  end

  @spec put_attachments(User.t(), Attachment.owner(), Common.T.id(), [Common.T.id()]) ::
          :ok | {:error, :too_many_attachments | :invalid_attachment}
  def put_attachments(%User{} = user, owner, id, media_ids) do
    PutAttachments.execute(user, owner, id, media_ids)
  end

  # Content made from other content shows the same files without uploading them again
  @spec link_attachments(Attachment.owner(), Common.T.id(), [Common.T.id()]) :: :ok
  def link_attachments(owner, id, media_ids), do: Attachment.insert_all(owner, id, media_ids)

  @spec list_attachments(Attachment.owner(), [Common.T.id()]) ::
          %{Common.T.id() => [Attachment.t()]}
  def list_attachments(owner, ids) when is_list(ids) do
    field = Attachment.owner_field(owner)

    owner
    |> Attachment.of(Enum.uniq(ids))
    |> Enum.group_by(&Map.fetch!(&1, field))
  end

  @spec read_images(Attachment.owner(), Common.T.id(), pos_integer()) ::
          {:ok, [binary()]} | {:error, term()}
  def read_images(owner, id, side \\ 256) do
    owner
    |> list_attachments([id])
    |> Map.get(id, [])
    |> Enum.map(& &1.media)
    |> Enum.filter(
      &(String.starts_with?(&1.content_type || "", "image/") and &1.status != :failed)
    )
    |> Enum.reduce_while({:ok, []}, fn media, {:ok, images} ->
      case read(image_key(media, side)) do
        {:ok, bytes} -> {:cont, {:ok, [bytes | images]}}
        error -> {:halt, error}
      end
    end)
    |> then(fn
      {:ok, images} -> {:ok, Enum.reverse(images)}
      error -> error
    end)
  end

  defp image_key(%Asset{variants: variants, bucket_key: original}, side) do
    smallest =
      variants
      |> Enum.filter(&(&1.format == :webp and &1.width >= side))
      |> Enum.min_by(& &1.width, fn -> nil end)

    if smallest, do: smallest.key, else: original
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp read(key) do
    TempFile.run(fn path ->
      with :ok <- Storage.download(key, path), do: File.read(path)
    end)
  end

  @spec delete_media(User.t(), Asset.t()) :: {:ok, Asset.t()} | {:error, :forbidden | term()}
  def delete_media(%User{id: id}, %Asset{uploader_id: id} = media) do
    DeleteMedia.execute(media)
  end

  def delete_media(%User{}, %Asset{}), do: {:error, :forbidden}

  defp with_upload(media) do
    upload(media) >>>
      then(&{:ok, %{media: media, upload: &1}})
  end

  defp upload(%Asset{status: :uploading, multipart_upload_id: nil} = media) do
    Storage.put_url(media.bucket_key, %{
      content_type: media.content_type,
      size: media.byte_size,
      sha256: media.sha256
    })
  end

  defp upload(%Asset{status: :uploading, multipart_upload_id: upload_id} = media) do
    part_size = Storage.part_size()

    {:ok, %{upload_id: upload_id, part_size: part_size, parts: ceil(media.byte_size / part_size)}}
  end

  defp upload(%Asset{}), do: {:ok, nil}

  defp part_url(media, number) do
    {:ok, url} = Storage.part_url(media.bucket_key, media.multipart_upload_id, number)
    url
  end
end
