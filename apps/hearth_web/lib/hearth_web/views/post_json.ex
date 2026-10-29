defmodule HearthWeb.PostJSON do
  alias HearthWeb.PageJSON
  alias HearthWeb.UserJSON

  @fields ~w[
    id
    community_id
    kind_id
    title
    body
    status
    answer_reply_id
    reply_count
    helpful_count
    last_activity_at
    edited_at
    inserted_at
  ]a

  def index(%{page: page} = assigns) do
    %{data: Enum.map(page.data, &serialize(&1, assigns)), meta: PageJSON.meta(page.meta)}
  end

  def pinned(%{posts: posts} = assigns), do: Enum.map(posts, &serialize(&1, assigns))

  def create(%{post: post} = assigns), do: serialize(post, assigns)
  def show(%{post: post} = assigns), do: serialize(post, assigns)
  def update(%{post: post} = assigns), do: serialize(post, assigns)
  def pin(%{post: post} = assigns), do: serialize(post, assigns)
  def lock(%{post: post} = assigns), do: serialize(post, assigns)
  def answer(%{post: post} = assigns), do: serialize(post, assigns)

  def helpful(%{on: on}), do: %{on: on}
  def watch(%{on: on}), do: %{on: on}
  def react(%{on: on}), do: %{on: on}

  @spec serialize(map(), map()) :: map()
  def serialize(post, %{authors: authors, attachments: attachments} = assigns) do
    post
    |> Map.take(@fields)
    |> Map.merge(%{
      author: UserJSON.summary(authors[post.author_id]),
      pinned: post.pinned_at != nil,
      locked: post.locked_at != nil,
      attachments: Map.get(attachments, post.id, []),
      reported: flagged?(assigns, :reported, post),
      in_review: flagged?(assigns, :in_review, post),
      watching: flagged?(assigns, :watching, post),
      live: live(assigns, post),
      from_chat: from_chat(post, authors),
      transcript: transcript(assigns, post),
      reactions: reactions(assigns, post),
      seen: flagged?(assigns, :seen, post)
    })
  end

  defp from_chat(%{source_message_count: nil}, _authors), do: nil

  defp from_chat(post, authors) do
    %{
      room_id: post.source_room_id,
      message_count: post.source_message_count,
      promoted_by: UserJSON.summary(authors[post.promoted_by_id])
    }
  end

  defp live(assigns, post) do
    case assigns |> Map.get(:live, %{}) |> Map.get(post.id) do
      nil -> nil
      session -> %{session_id: session.id, room_id: session.room_id, mode: session.mode}
    end
  end

  defp transcript(assigns, post) do
    case assigns |> Map.get(:transcripts, %{}) |> Map.get(post.id) do
      nil ->
        nil

      %{transcript: transcript, room_name: room_name} ->
        %{
          session_id: transcript.session_id,
          room_name: room_name,
          duration_ms: transcript.duration_ms
        }
    end
  end

  # Views that don't load reactions, such as a new post, have none
  defp reactions(assigns, post),
    do: assigns |> Map.get(:reactions, %{}) |> Map.get(post.id, [])

  # Views that don't load reports leave the flags off, which reads as false
  defp flagged?(assigns, key, post),
    do: assigns |> Map.get(key, MapSet.new()) |> MapSet.member?(post.id)
end
