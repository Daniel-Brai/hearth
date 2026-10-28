defmodule Hearth.Repo.Migrations.CreateCommunitiesInvitesTable do
  use Ecto.Migration

  @prefix :communities
  @table :invites

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :community_id, references(:communities, type: :uuid, on_delete: :delete_all),
        null: false

      add :created_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :code, :string, null: false
      add :role_key, :string, null: false, default: "member"
      add :max_uses, :integer, null: true
      add :uses_count, :integer, null: false, default: 0
      add :expires_at, :timestamptz, null: true
      add :revoked_at, :timestamptz, null: true

      timestamps()
    end

    create unique_index(@table, :code, prefix: @prefix)
    create index(@table, :community_id, prefix: @prefix)
  end
end
