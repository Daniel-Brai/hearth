defmodule HearthWeb.Schema.AuthoredReply do
  use JSV.Schema

  alias HearthWeb.Schema.Reply

  defschema %{
    title: "AuthoredReply",
    type: :object,
    required: ~w[reply post answer]a,
    properties: %{
      reply: Reply,
      post: %{
        type: :object,
        required: ~w[id title community_id]a,
        properties: %{id: uuid(), title: string(), community_id: uuid()}
      },
      answer: boolean()
    }
  }
end
