defmodule Hearth.Forum.ReplyCreated do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[
    reply_id
    post_id
    parent_reply_id
    community_id
    author_id
    parent_author_id
    post_author_id
  ]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          reply_id: T.id(),
          post_id: T.id(),
          parent_reply_id: nil | T.id(),
          community_id: T.id(),
          author_id: T.id(),
          parent_author_id: nil | T.id(),
          post_author_id: nil | T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{post_id: id}), do: "post:#{id}"
end
