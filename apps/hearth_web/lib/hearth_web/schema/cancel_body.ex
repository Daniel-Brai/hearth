defmodule HearthWeb.Schema.CancelBody do
  use JSV.Schema

  defschema %{
    title: "CancelBody",
    type: :object,
    required: [:cancelled],
    additionalProperties: false,
    properties: %{cancelled: boolean()}
  }
end
