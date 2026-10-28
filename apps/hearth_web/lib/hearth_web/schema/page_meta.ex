defmodule HearthWeb.Schema.PageMeta do
  use JSV.Schema

  defschema %{
    title: "PageMeta",
    type: :object,
    required: ~w[after before has_next has_previous]a,
    properties: %{
      after: nullable(string(description: "Cursor for the next page")),
      before: nullable(string(description: "Cursor for the page before")),
      has_next: boolean(),
      has_previous: boolean()
    }
  }
end
