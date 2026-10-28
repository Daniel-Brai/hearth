defmodule HearthWeb.Schema.MyInvite do
  use JSV.Schema

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
          hue: enum(~w[ink blue violet purple pink red orange yellow green aqua]),
          logo_id: nullable(uuid())
        }
      },
      expires_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time")
    }
  }
end
