defmodule HearthWeb.Schema.Event.ContentRestored do
  use JSV.Schema

  alias Hearth.Moderation.Item
  alias HearthWeb.Schema

  defschema %{
    title: "ContentRestored",
    type: :object,
    description:
      "Goes to the room or conversation for a message, the post for a reply, the community and the post for a post",
    required: ~w[subject_type subject_id community_id room_id post_id conversation_id]a,
    properties: %{
      subject_type: Schema.enum_of(Item, :subject_type),
      subject_id: uuid(),
      community_id: nullable(uuid()),
      room_id: nullable(uuid()),
      post_id: nullable(uuid()),
      conversation_id: nullable(uuid())
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Moderation.ContentRestored
end
