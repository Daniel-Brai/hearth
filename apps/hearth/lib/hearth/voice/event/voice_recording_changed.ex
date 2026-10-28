defmodule Hearth.Voice.VoiceRecordingChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T
  alias Hearth.Voice.Recording

  @fields ~w[
    session_id
    post_id
    community_id
    room_id
    recording_id
    status
    started_by_id
    started_at
  ]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          session_id: T.id(),
          post_id: nil | T.id(),
          community_id: T.id(),
          room_id: T.id(),
          recording_id: T.id(),
          status: Recording.status(),
          started_by_id: nil | T.id(),
          started_at: DateTime.t()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{} = event) do
    topics = ["community:#{event.community_id}", "voice:#{event.session_id}"]

    if event.post_id, do: ["post:#{event.post_id}" | topics], else: topics
  end
end
