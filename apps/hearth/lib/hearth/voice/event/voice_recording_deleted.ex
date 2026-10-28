defmodule Hearth.Voice.VoiceRecordingDeleted do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[recording_id session_id post_id community_id room_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          recording_id: T.id(),
          session_id: T.id(),
          post_id: nil | T.id(),
          community_id: T.id(),
          room_id: T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{} = event) do
    topic = "community:#{event.community_id}"

    if event.post_id, do: ["post:#{event.post_id}", topic], else: [topic]
  end
end
