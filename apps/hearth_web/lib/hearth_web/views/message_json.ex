defmodule HearthWeb.MessageJSON do
  alias HearthWeb.Attachments
  alias HearthWeb.PageJSON
  alias HearthWeb.UserJSON

  @fields ~w[
    id
    room_id
    conversation_id
    reply_to_id
    depth
    child_count
    status
    kind
    post_id
    edited_at
    inserted_at
  ]a

  def index(%{page: page} = assigns) do
    %{data: Enum.map(page.data, &serialize(&1, assigns)), meta: PageJSON.meta(page.meta)}
  end

  def create(%{message: message} = assigns), do: serialize(message, assigns)
  def update(%{message: message} = assigns), do: serialize(message, assigns)

  def react(%{on: on}), do: %{on: on}

  def list_scheduled(%{scheduled: scheduled, media: media}),
    do: Enum.map(scheduled, &serialize_scheduled(&1, media))

  def scheduled(%{scheduled: scheduled, media: media}), do: serialize_scheduled(scheduled, media)

  @spec serialize(map(), map()) :: map()
  def serialize(message, %{authors: authors, attachments: attachments} = assigns) do
    deleted = message.deleted_at != nil
    # Removed by a moderator reads as a marker, like a deleted one
    hidden = deleted or message.status == :removed

    message
    |> Map.take(@fields)
    |> Map.merge(%{
      author: if(hidden, do: nil, else: UserJSON.summary(authors[message.author_id])),
      body: if(hidden, do: nil, else: message.body),
      deleted: deleted,
      attachments: if(hidden, do: [], else: Map.get(attachments, message.id, [])),
      reactions: if(hidden, do: [], else: reactions(assigns, message)),
      preview_hidden: message.preview_hidden_at != nil,
      mentions_all: not hidden and assigns |> mentions_all() |> MapSet.member?(message.id)
    })
  end

  defp mentions_all(assigns), do: Map.get(assigns, :mentions_all, MapSet.new())

  # Views that don't load reactions, such as a new message, have none
  defp reactions(assigns, message),
    do: assigns |> Map.get(:reactions, %{}) |> Map.get(message.id, [])

  defp serialize_scheduled(scheduled, media) do
    scheduled
    |> Map.take(~w[id room_id conversation_id body send_at failure]a)
    |> Map.put(:attachments, Attachments.pick(scheduled.attachment_ids, media))
  end

  def unread(%{unread: %{rooms: rooms, conversations: conversations}}) do
    %{
      rooms: Enum.map(rooms, &%{id: &1.room_id, community_id: &1.community_id, count: &1.count}),
      conversations: Enum.map(conversations, fn {id, count} -> %{id: id, count: count} end)
    }
  end
end
