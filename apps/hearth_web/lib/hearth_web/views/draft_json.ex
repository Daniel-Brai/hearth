defmodule HearthWeb.DraftJSON do
  @fields ~w[community_id kind_id title body updated_at]a

  def index(%{drafts: drafts}), do: Enum.map(drafts, &serialize/1)
  def show(%{draft: draft}), do: serialize(draft)

  defp serialize(draft), do: draft |> Map.take(@fields) |> Map.put(:kind, kind(draft.kind))

  # A saved draft answers without its kind loaded since the writer already knows it
  defp kind(%{label: label}), do: label
  defp kind(_none), do: nil
end
