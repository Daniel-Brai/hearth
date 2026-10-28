defmodule HearthWeb.Schema.TransferBody do
  use JSV.Schema

  defschema %{
    title: "TransferBody",
    type: :object,
    required: [:user_id, :code],
    additionalProperties: false,
    properties: %{
      user_id: uuid(),
      code: string(pattern: "^[0-9]{6}$", description: "The code emailed to the Owner")
    }
  }
end
