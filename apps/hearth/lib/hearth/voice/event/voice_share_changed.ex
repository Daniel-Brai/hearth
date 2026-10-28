defmodule Hearth.Voice.VoiceShareChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields [:session_id, :user_id]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          session_id: T.id(),
          user_id: nil | T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{session_id: id}), do: "voice:#{id}"
end
