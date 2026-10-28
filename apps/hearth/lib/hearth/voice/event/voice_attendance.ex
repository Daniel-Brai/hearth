defmodule Hearth.Voice.VoiceAttendance do
  # Who is in a live room and how many, for people outside it
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[session_id room_id community_id people user_ids]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          session_id: T.id(),
          room_id: T.id(),
          community_id: T.id(),
          people: non_neg_integer(),
          user_ids: [T.id()]
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "community:#{id}"
end
