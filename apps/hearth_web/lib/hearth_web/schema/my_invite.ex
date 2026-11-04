defmodule HearthWeb.Schema.MyInvite do
  use JSV.Schema

  alias Hearth.Communities.Community
  alias HearthWeb.Schema
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "MyInvite",
    type: :object,
    required: ~w[id code role_key inviter community expires_at inserted_at]a,
    properties: %{
      id: uuid(),
      code: string(),
      role_key: string(),
      inviter: nullable(UserSummary),
      community: %{
        type: :object,
        required: ~w[id slug name tagline hue logo_id]a,
        properties: %{
          id: uuid(),
          slug: string(),
          name: string(),
          tagline: nullable(string()),
          hue: Schema.enum_of(Community, :hue),
          logo_id: nullable(uuid())
        }
      },
      expires_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time")
    }
  }
end
