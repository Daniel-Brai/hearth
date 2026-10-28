defmodule HearthWeb.Schema.PartUrlsBody do
  use JSV.Schema

  defschema %{
    title: "PartUrlsBody",
    type: :object,
    required: [:numbers],
    additionalProperties: false,
    properties: %{
      numbers:
        array_of(integer(minimum: 1, maximum: 10_000),
          minItems: 1,
          maxItems: 100,
          uniqueItems: true
        )
    }
  }
end
