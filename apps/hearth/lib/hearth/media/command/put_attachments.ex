defmodule Hearth.Media.Command.PutAttachments do
  alias Hearth.Accounts.User
  alias Hearth.Common
  alias Hearth.Media.Asset
  alias Hearth.Media.Attachment
  alias Hearth.Media.FileType

  @usable [:processing, :ready]

  @spec execute(User.t(), Attachment.owner(), Common.T.id(), [Common.T.id()]) ::
          :ok | {:error, :too_many_attachments | :invalid_attachment}
  def execute(%User{} = user, owner, id, media_ids) when is_list(media_ids) do
    media_ids = Enum.uniq(media_ids)

    with :ok <- within_cap(media_ids),
         :ok <- usable(user, media_ids),
         :ok <- Attachment.delete_of(owner, id) do
      Attachment.insert_all(owner, id, media_ids)
    end
  end

  defp within_cap(media_ids) do
    case length(media_ids) <= FileType.max_attachments() do
      true -> :ok
      false -> {:error, :too_many_attachments}
    end
  end

  defp usable(_user, []), do: :ok

  defp usable(%User{id: user_id}, media_ids) do
    with true <- Enum.all?(media_ids, &Common.valid_id?/1),
         found =
           Asset.all(id: media_ids, uploader_id: user_id, purpose: :attachment, status: @usable),
         true <- length(found) == length(media_ids) do
      :ok
    else
      false -> {:error, :invalid_attachment}
    end
  end
end
