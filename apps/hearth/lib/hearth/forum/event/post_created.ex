defmodule Hearth.Forum.PostCreated do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[post_id community_id author_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          post_id: T.id(),
          community_id: T.id(),
          author_id: T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "community:#{id}"
end
