defmodule HearthWeb.Schema.SignInBody do
  use JSV.Schema

  defschema %{
    title: "SignInBody",
    type: :object,
    required: [:email, :code],
    additionalProperties: false,
    properties: %{
      email: string(minLength: 3, maxLength: 254),
      code: string(pattern: "^[0-9]{6}$")
    }
  }
end
