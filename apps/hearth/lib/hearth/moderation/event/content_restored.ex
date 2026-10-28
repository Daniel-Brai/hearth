defmodule Hearth.Moderation.ContentRestored do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields ~w[subject_type subject_id community_id room_id post_id conversation_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          subject_type: :post | :reply | :message,
          subject_id: T.id(),
          community_id: nil | T.id(),
          room_id: nil | T.id(),
          post_id: nil | T.id(),
          conversation_id: nil | T.id()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{subject_type: :message, room_id: nil, conversation_id: id}),
    do: "conversation:#{id}"

  def broadcast_on(%__MODULE__{subject_type: :message, room_id: id}), do: "room:#{id}"
  def broadcast_on(%__MODULE__{subject_type: :reply, post_id: id}), do: "post:#{id}"

  def broadcast_on(%__MODULE__{subject_type: :post, community_id: community_id, post_id: id}),
    do: ["community:#{community_id}", "post:#{id}"]
end
