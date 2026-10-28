defmodule Hearth.Repo.Migrations.CreateAuthUserIdentitiesTable do
  use Ecto.Migration

  @prefix :auth
  @table :user_identities

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: false

      add :provider, :string, null: false
      add :provider_uid, :string, null: false
      add :email, :citext, null: true

      timestamps()
    end

    create unique_index(@table, [:provider, :provider_uid], prefix: @prefix)
    create unique_index(@table, [:user_id, :provider], prefix: @prefix)
  end
end
