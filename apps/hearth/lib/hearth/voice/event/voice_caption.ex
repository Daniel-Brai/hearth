defmodule Hearth.Voice.VoiceCaption do
  # A line of what someone said, for the people in the room who turned captions on
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[session_id user_id text]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{session_id: T.id(), user_id: T.id(), text: String.t()}

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{session_id: id}), do: "voice:#{id}"
end
