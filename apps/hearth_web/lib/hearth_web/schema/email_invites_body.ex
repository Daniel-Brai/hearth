defmodule HearthWeb.Schema.EmailInvitesBody do
  use JSV.Schema

  defschema %{
    title: "EmailInvitesBody",
    type: :object,
    required: [:emails],
    additionalProperties: false,
    properties: %{
      note: nullable(string(maxLength: 280, description: "Put in each email")),
      emails:
        array_of(
          %{
            type: :object,
            required: [:email, :role_key],
            additionalProperties: false,
            properties: %{
              email: string(minLength: 3, maxLength: 254),
              role_key: string(minLength: 1, maxLength: 40)
            }
          },
          minItems: 1,
          maxItems: 50
        )
    }
  }
end
