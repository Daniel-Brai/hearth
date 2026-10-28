defmodule HearthWeb.Schema.PushEndpointBody do
  use JSV.Schema

  defschema %{
    title: "PushEndpointBody",
    type: :object,
    required: [:endpoint],
    additionalProperties: false,
    properties: %{endpoint: string(maxLength: 2000)}
  }
end
