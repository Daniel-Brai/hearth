defmodule Hearth.Repo.Migrations.CreateAuthUserTokensTable do
  use Ecto.Migration

  @prefix :auth
  @table :user_tokens

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: true

      add :context, :string, null: false
      add :token_hash, :binary, null: false
      add :sent_to, :citext, null: true
      add :data, :map, null: false, default: %{}
      add :attempts, :integer, null: false, default: 0
      add :user_agent, :text, null: true
      add :ip, :string, null: true
      add :expires_at, :timestamptz, null: false

      timestamps(updated_at: false)
    end

    create unique_index(@table, :token_hash, prefix: @prefix)
    create index(@table, [:context, :sent_to], prefix: @prefix)
    create index(@table, [:user_id, :context], prefix: @prefix)
    create index(@table, :expires_at, prefix: @prefix)
  end
end
