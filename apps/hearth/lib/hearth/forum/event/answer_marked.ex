defmodule Hearth.Forum.AnswerMarked do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[post_id reply_id reply_author_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          post_id: T.id(),
          reply_id: T.id(),
          reply_author_id: nil | T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{post_id: id}), do: "post:#{id}"
end
