defmodule HearthWeb.Schema.Event.MemberJoined do
  use JSV.Schema

  defschema %{
    title: "MemberJoined",
    type: :object,
    description: "On community:<id>",
    required: [:community_id, :user_id],
    properties: %{
      community_id: uuid(),
      user_id: uuid()
    }
  }

  @spec event() :: module()
  def event, do: Hearth.Communities.MemberJoined
end
