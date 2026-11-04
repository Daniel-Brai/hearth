defmodule HearthWeb.Schema.Privacy do
  use JSV.Schema

  alias Hearth.Accounts
  alias HearthWeb.Schema

  @audience Schema.enum_of(Accounts.Privacy, :presence)

  defschema %{
    title: "Privacy",
    type: :object,
    required: ~w[show_name show_communities presence last_seen avatar]a,
    additionalProperties: false,
    properties: %{
      show_name: boolean(description: "False shows only the username"),
      show_communities: Schema.enum_of(Accounts.Privacy, :show_communities),
      presence: @audience,
      last_seen: @audience,
      avatar: @audience
    }
  }
end
