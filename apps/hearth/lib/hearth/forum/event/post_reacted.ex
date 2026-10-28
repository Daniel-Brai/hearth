defmodule Hearth.Forum.PostReacted do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[post_id community_id user_id emoji on count]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          post_id: T.id(),
          community_id: T.id(),
          user_id: T.id(),
          emoji: String.t(),
          on: boolean(),
          count: non_neg_integer()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{post_id: id}), do: "post:#{id}"
end
