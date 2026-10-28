defmodule Hearth.Repo.Migrations.CreateIamMembershipsTable do
  use Ecto.Migration

  @prefix :iam
  @table :memberships

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      # References communities once that context's tables exist
      add :community_id, :uuid, null: false

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: false

      add :joined_at, :timestamptz, null: false

      timestamps()
    end

    create unique_index(@table, [:community_id, :user_id], prefix: @prefix)
    create index(@table, :user_id, prefix: @prefix)
  end
end
