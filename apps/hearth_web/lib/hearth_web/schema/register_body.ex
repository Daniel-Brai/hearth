defmodule HearthWeb.Schema.RegisterBody do
  use JSV.Schema

  defschema %{
    title: "RegisterBody",
    type: :object,
    required: [:sign_up_token, :username],
    additionalProperties: false,
    properties: %{
      sign_up_token: string(minLength: 1, maxLength: 64),
      username: string(minLength: 3, maxLength: 20),
      display_name: nullable(string(minLength: 1, maxLength: 60))
    }
  }
end
