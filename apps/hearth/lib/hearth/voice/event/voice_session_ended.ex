defmodule Hearth.Voice.VoiceSessionEnded do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[session_id room_id community_id post_id reason]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          session_id: T.id(),
          room_id: T.id(),
          community_id: T.id(),
          post_id: nil | T.id(),
          reason: :ended | :lost
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{} = event) do
    topics = ["community:#{event.community_id}", "voice:#{event.session_id}"]

    if event.post_id, do: ["post:#{event.post_id}" | topics], else: topics
  end
end
