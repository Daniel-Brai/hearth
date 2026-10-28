defmodule HearthWeb.Schema.UsernameAvailability do
  use JSV.Schema

  defschema %{
    title: "UsernameAvailability",
    type: :object,
    required: [:available],
    properties: %{available: boolean()}
  }
end
