defmodule HearthWeb.Schema do
  import JSV.Schema.Helpers

  alias HearthWeb.Schema.PageMeta

  @spec page(module()) :: map()
  def page(item) when is_atom(item) do
    object(required: [:data, :meta], properties: %{data: array_of(item), meta: PageMeta})
  end

  @spec paging() :: keyword()
  def paging do
    [
      limit: [in: :query, schema: integer(minimum: 1, maximum: 50)],
      after: [in: :query, schema: string()],
      before: [in: :query, schema: string()]
    ]
  end
end
