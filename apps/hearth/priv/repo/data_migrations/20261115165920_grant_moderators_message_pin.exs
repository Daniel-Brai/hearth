defmodule Hearth.Repo.Migrations.GrantModeratorsMessagePin do
  use Ecto.Migration

  import Ecto.Query

  @disable_ddl_transaction true
  @disable_migration_lock true

  @batch 500

  # Communities made before message.pin existed give it to their Moderator role as new ones do
  def up, do: grant(nil)

  def down, do: :ok

  defp grant(last) do
    ids = last |> missing() |> repo().all()

    query =
      from r in "roles",
        prefix: "iam",
        where: r.id in ^ids,
        update: [set: [permissions: fragment("array_append(?, 'message.pin')", r.permissions)]]

    repo().update_all(query, [])

    case length(ids) < @batch do
      true -> :ok
      false -> ids |> List.last() |> grant()
    end
  end

  defp missing(last) do
    query =
      from r in "roles",
        prefix: "iam",
        where: r.key == "moderator",
        where: not fragment("'message.pin' = ANY(?)", r.permissions),
        order_by: r.id,
        limit: @batch,
        select: r.id

    case last do
      nil -> query
      id -> where(query, [r], r.id > ^id)
    end
  end
end
