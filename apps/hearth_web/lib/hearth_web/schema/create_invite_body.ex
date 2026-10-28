defmodule HearthWeb.Schema.CreateInviteBody do
  use JSV.Schema

  defschema %{
    title: "CreateInviteBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      role_key: string(minLength: 1, maxLength: 40),
      max_uses: nullable(integer(minimum: 1, maximum: 10_000)),
      expires_at: nullable(string(format: :"date-time"))
    }
  }
end
