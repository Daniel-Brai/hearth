defmodule Hearth.Voice.VoiceSpeakingChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields [:session_id, :user_ids]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          session_id: T.id(),
          user_ids: [T.id()]
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{session_id: id}), do: "voice:#{id}"
end
