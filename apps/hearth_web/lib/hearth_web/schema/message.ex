defmodule HearthWeb.Schema.Message do
  use JSV.Schema

  defschema %{
    title: "Message",
    type: :object,
    required: [:message],
    properties: %{
      message: string(),
      code: string(description: "Stable, such as invalid_token")
    }
  }
end
