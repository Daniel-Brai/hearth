defmodule HearthWeb.Schema.UpdatePollBody do
  use JSV.Schema

  defschema %{
    title: "UpdatePollBody",
    type: :object,
    required: [:closed],
    additionalProperties: false,
    properties: %{closed: const(true, description: "Closes it for good")}
  }
end
