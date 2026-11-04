defmodule HearthWeb.Schema do
  import JSV.Schema.Helpers

  alias HearthWeb.Schema.PageMeta

  @spec page(module()) :: map()
  def page(item) when is_atom(item) do
    object(required: [:data, :meta], properties: %{data: array_of(item), meta: PageMeta})
  end

  # The values come from the domain field so the API can't drift from what is stored
  @spec enum_of(module(), atom(), keyword()) :: map()
  def enum_of(schema, field, opts \\ []) when is_atom(schema) and is_atom(field),
    do: enum(Ecto.Enum.dump_values(schema, field), opts)

  @spec paging() :: keyword()
  def paging do
    [
      limit: [in: :query, schema: integer(minimum: 1, maximum: 50)],
      after: [in: :query, schema: string()],
      before: [in: :query, schema: string()]
    ]
  end
end
