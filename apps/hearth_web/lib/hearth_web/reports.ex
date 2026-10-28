defmodule HearthWeb.Reports do
  alias Hearth.Moderation

  @spec load([map()] | map(), nil | Hearth.Accounts.User.t(), :post | :reply | :message) ::
          MapSet.t(String.t())
  def load(items, auth, type) do
    ids = items |> List.wrap() |> Enum.map(& &1.id)

    Moderation.reported_by(auth, type, ids)
  end

  @spec in_review([map()] | map(), :post | :reply | :message) :: MapSet.t(String.t())
  def in_review(items, type) do
    ids = items |> List.wrap() |> Enum.map(& &1.id)

    Moderation.in_review(type, ids)
  end
end
