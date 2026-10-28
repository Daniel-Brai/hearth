defmodule HearthWeb.Schema.Privacy do
  use JSV.Schema

  @audience enum(~w[everyone members nobody])

  defschema %{
    title: "Privacy",
    type: :object,
    required: ~w[show_name show_communities presence last_seen avatar]a,
    additionalProperties: false,
    properties: %{
      show_name: boolean(description: "False shows only the username"),
      show_communities: enum(~w[common everyone nobody]),
      presence: @audience,
      last_seen: @audience,
      avatar: @audience
    }
  }
end
