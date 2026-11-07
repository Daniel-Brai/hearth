defmodule HearthWeb.Schema.PostSearchHit do
  use JSV.Schema

  alias HearthWeb.Schema.Post

  defschema %{
    title: "PostSearchHit",
    type: :object,
    required: ~w[post reply_id excerpt]a,
    properties: %{
      post: Post,
      reply_id: nullable(uuid(description: "The reply that matched when the post itself didn't")),
      excerpt: string(description: "Plain text around the first match")
    }
  }
end
