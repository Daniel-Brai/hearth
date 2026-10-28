defmodule HearthWeb.Schema.RequestCodeBody do
  use JSV.Schema

  defschema %{
    title: "RequestCodeBody",
    type: :object,
    required: [:email],
    additionalProperties: false,
    properties: %{
      email: string(minLength: 3, maxLength: 254)
    }
  }
end
