defmodule Hearth.Voice.VoiceParticipantChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T
  alias Hearth.Voice.Participant

  @fields ~w[session_id user_id role hand_raised_at self_muted server_muted left]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          session_id: T.id(),
          user_id: T.id(),
          role: nil | Participant.role(),
          hand_raised_at: nil | DateTime.t(),
          self_muted: boolean(),
          server_muted: boolean(),
          left: boolean()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{session_id: id}), do: "voice:#{id}"
end
