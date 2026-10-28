defmodule Hearth.Voice.VoiceReaction do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[session_id user_id emoji]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          session_id: T.id(),
          user_id: T.id(),
          emoji: String.t()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{session_id: id}), do: "voice:#{id}"
end
