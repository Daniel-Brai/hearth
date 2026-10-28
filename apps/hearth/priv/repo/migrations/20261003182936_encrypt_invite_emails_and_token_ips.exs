defmodule Hearth.Repo.Migrations.EncryptInviteEmailsAndTokenIps do
  use Ecto.Migration

  import Ecto.Query

  alias Hearth.Vault

  @batch 1_000

  def up do
    :ok = Vault.load!()

    alter table(:invite_emails, prefix: "communities") do
      add :sealed_email, :binary
      add :email_hash, :binary
    end

    flush()

    rewrite("communities", "invite_emails", :email, fn email ->
      [sealed_email: Vault.encrypt(email), email_hash: email |> normalize() |> Vault.hash()]
    end)

    drop unique_index(:invite_emails, [:invite_id, :email], prefix: "communities")

    alter table(:invite_emails, prefix: "communities") do
      remove :email
    end

    rename table(:invite_emails, prefix: "communities"), :sealed_email, to: :email

    execute "ALTER TABLE communities.invite_emails ALTER COLUMN email SET NOT NULL"
    execute "ALTER TABLE communities.invite_emails ALTER COLUMN email_hash SET NOT NULL"

    create unique_index(:invite_emails, [:invite_id, :email_hash], prefix: "communities")
    create index(:invite_emails, [:email_hash], prefix: "communities")

    alter table(:user_tokens, prefix: "auth") do
      add :sealed_ip, :binary
    end

    flush()

    rewrite("auth", "user_tokens", :ip, &[sealed_ip: Vault.encrypt(&1)])

    alter table(:user_tokens, prefix: "auth") do
      remove :ip
    end

    rename table(:user_tokens, prefix: "auth"), :sealed_ip, to: :ip
  end

  def down do
    :ok = Vault.load!()

    alter table(:user_tokens, prefix: "auth") do
      add :plain_ip, :string
    end

    flush()

    rewrite("auth", "user_tokens", :ip, &[plain_ip: open!(&1)])

    alter table(:user_tokens, prefix: "auth") do
      remove :ip
    end

    rename table(:user_tokens, prefix: "auth"), :plain_ip, to: :ip

    drop index(:invite_emails, [:email_hash], prefix: "communities")
    drop unique_index(:invite_emails, [:invite_id, :email_hash], prefix: "communities")

    alter table(:invite_emails, prefix: "communities") do
      add :plain_email, :citext
    end

    flush()

    rewrite("communities", "invite_emails", :email, &[plain_email: open!(&1)])

    alter table(:invite_emails, prefix: "communities") do
      remove :email
      remove :email_hash
    end

    rename table(:invite_emails, prefix: "communities"), :plain_email, to: :email

    execute "ALTER TABLE communities.invite_emails ALTER COLUMN email SET NOT NULL"

    create unique_index(:invite_emails, [:invite_id, :email], prefix: "communities")
  end

  defp normalize(email), do: email |> String.trim() |> String.downcase()

  defp open!(sealed) do
    {:ok, plain} = Vault.decrypt(sealed)
    plain
  end

  defp rewrite(prefix, table, column, changes) do
    nil
    |> Stream.unfold(&next_batch(prefix, table, column, &1))
    |> Stream.each(&write_batch(&1, prefix, table, changes))
    |> Stream.run()
  end

  defp next_batch(prefix, table, column, after_id) do
    case batch(prefix, table, column, after_id) do
      [] -> nil
      rows -> {rows, rows |> List.last() |> elem(0)}
    end
  end

  defp write_batch(rows, prefix, table, changes) do
    for {id, value} <- rows, value != nil do
      query = from(r in table, prefix: ^prefix, where: r.id == type(^id, :binary_id))

      repo().update_all(query, set: changes.(value))
    end
  end

  defp batch(prefix, table, column, after_id) do
    query =
      from(r in table,
        prefix: ^prefix,
        order_by: r.id,
        limit: @batch,
        select: {type(r.id, :binary_id), field(r, ^column)}
      )

    query
    |> after_id(after_id)
    |> repo().all()
  end

  defp after_id(query, nil), do: query
  defp after_id(query, id), do: where(query, [r], r.id > type(^id, :binary_id))
end
