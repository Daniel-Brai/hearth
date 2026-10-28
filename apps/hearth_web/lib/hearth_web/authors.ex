defmodule HearthWeb.Authors do
  alias Hearth.Accounts
  alias HearthWeb.Avatars

  @spec load([map()] | map()) :: %{optional(String.t()) => map()}
  def load(items) do
    items
    |> List.wrap()
    |> Enum.flat_map(&[&1.author_id, Map.get(&1, :promoted_by_id)])
    |> people()
  end

  @spec people([nil | String.t()]) :: %{optional(String.t()) => map()}
  def people(ids) when is_list(ids) do
    ids
    |> Enum.reject(&is_nil/1)
    |> Accounts.list_users()
    |> Avatars.put_urls()
    |> Map.new(&{&1.id, &1})
  end
end
