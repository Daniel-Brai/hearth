defmodule HearthWeb.Schema.Conversation do
  use JSV.Schema

  alias Hearth.Chat
  alias HearthWeb.Schema
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "Conversation",
    type: :object,
    required: [:id, :kind, :name, :member_ids, :members],
    properties: %{
      id: uuid(),
      kind: Schema.enum_of(Chat.Conversation, :kind),
      name: nullable(string()),
      member_ids: array_of(uuid()),
      members: array_of(UserSummary, description: "Everyone in it, the viewer too")
    }
  }
end
