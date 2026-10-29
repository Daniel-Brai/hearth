defmodule Hearth.Transcripts.TranscriptReady do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[transcript_id session_id recording_id community_id room_id post_id event_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          transcript_id: T.id(),
          session_id: T.id(),
          recording_id: T.id(),
          community_id: T.id(),
          room_id: nil | T.id(),
          post_id: nil | T.id(),
          event_id: nil | T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{} = event) do
    topics = ["rooms:#{event.community_id}"]

    if event.post_id, do: ["post:#{event.post_id}" | topics], else: topics
  end
end
