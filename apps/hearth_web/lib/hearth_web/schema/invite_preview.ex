defmodule HearthWeb.Schema.InvitePreview do
  use JSV.Schema

  defschema %{
    title: "InvitePreview",
    type: :object,
    required: [:code, :usable, :role_key, :role_name, :inviter, :community],
    properties: %{
      code: string(),
      usable: boolean(description: "False once revoked, expired or used up"),
      role_key: string(),
      role_name: string(),
      inviter: nullable(HearthWeb.Schema.UserSummary),
      community: %{
        type: :object,
        required: ~w[id slug name tagline hue logo_id logo_url member_count]a,
        properties: %{
          id: uuid(),
          slug: string(),
          name: string(),
          tagline: nullable(string()),
          hue: enum(~w[ink blue violet purple pink red orange yellow green aqua]),
          logo_id: nullable(uuid()),
          logo_url: nullable(string(description: "Null without one or while processing")),
          member_count: non_neg_integer()
        }
      }
    }
  }
end
