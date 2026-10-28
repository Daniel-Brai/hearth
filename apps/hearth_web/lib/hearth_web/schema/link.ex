defmodule HearthWeb.Schema.Link do
  use JSV.Schema

  defschema %{
    title: "Link",
    type: :object,
    required: [:url, :label],
    properties: %{url: string(maxLength: 2_000), label: nullable(string(maxLength: 40))}
  }
end
