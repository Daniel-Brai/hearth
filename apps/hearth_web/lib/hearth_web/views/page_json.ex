defmodule HearthWeb.PageJSON do
  @spec meta(map()) :: map()
  def meta(meta) do
    %{
      after: meta.end_cursor,
      before: meta.start_cursor,
      has_next: meta.has_next_page? == true,
      has_previous: meta.has_previous_page? == true
    }
  end
end
