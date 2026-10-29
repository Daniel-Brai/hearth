defmodule Hearth.Communities.RoomAccessChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  # A room's access changed when room_id is set, one member's roles when user_id is set,
  # and a role's permissions when both are nil
  @enforce_keys [:community_id]
  defstruct ~w[community_id room_id user_id]a

  @type t :: %__MODULE__{
          community_id: T.id(),
          room_id: nil | T.id(),
          user_id: nil | T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "rooms:#{id}"
end
