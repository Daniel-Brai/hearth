defmodule Hearth.Repo.Migrations.EncryptChatMessageBodies do
  use Ecto.Migration

  import Ecto.Query

  alias Hearth.Vault

  @prefix "chat"
  @batch 1_000

  def up do
    alter table(:messages, prefix: @prefix) do
      add :sealed_body, :binary
    end

    flush()

    rewrite(:body, :sealed_body, &Vault.encrypt/1)

    alter table(:messages, prefix: @prefix) do
      remove :body
    end

    rename table(:messages, prefix: @prefix), :sealed_body, to: :body

    execute "ALTER TABLE chat.messages ALTER COLUMN body SET NOT NULL"
  end

  def down do
    alter table(:messages, prefix: @prefix) do
      add :plain_body, :text
    end

    flush()

    rewrite(:body, :plain_body, fn sealed ->
      {:ok, plain} = Vault.decrypt(sealed)
      plain
    end)

    alter table(:messages, prefix: @prefix) do
      remove :body
    end

    rename table(:messages, prefix: @prefix), :plain_body, to: :body

    execute "ALTER TABLE chat.messages ALTER COLUMN body SET NOT NULL"
  end

  defp rewrite(from, to, fun) do
    :ok = Vault.load!()

    nil
    |> Stream.unfold(&next_batch(from, &1))
    |> Stream.each(&write_batch(&1, to, fun))
    |> Stream.run()
  end

  defp next_batch(from, after_id) do
    case batch(from, after_id) do
      [] -> nil
      rows -> {rows, rows |> List.last() |> elem(0)}
    end
  end

  defp write_batch(rows, to, fun) do
    for {id, value} <- rows do
      query = from(m in "messages", prefix: ^@prefix, where: m.id == type(^id, :binary_id))

      repo().update_all(query, set: [{to, fun.(value)}])
    end
  end

  defp batch(from, after_id) do
    query =
      from(m in "messages",
        prefix: ^@prefix,
        order_by: m.id,
        limit: @batch,
        select: {type(m.id, :binary_id), field(m, ^from)}
      )

    query
    |> after_id(after_id)
    |> repo().all()
  end

  defp after_id(query, nil), do: query
  defp after_id(query, id), do: where(query, [m], m.id > type(^id, :binary_id))
end
