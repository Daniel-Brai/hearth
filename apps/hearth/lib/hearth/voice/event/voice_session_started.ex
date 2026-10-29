defmodule Hearth.Voice.VoiceSessionStarted do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T
  alias Hearth.Voice.Session

  @fields ~w[session_id room_id community_id host_id mode topic post_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          session_id: T.id(),
          room_id: T.id(),
          community_id: T.id(),
          host_id: nil | T.id(),
          mode: Session.mode(),
          topic: nil | String.t(),
          post_id: nil | T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id, post_id: nil}), do: "rooms:#{id}"

  def broadcast_on(%__MODULE__{community_id: id, post_id: post_id}),
    do: ["rooms:#{id}", "post:#{post_id}"]
end
