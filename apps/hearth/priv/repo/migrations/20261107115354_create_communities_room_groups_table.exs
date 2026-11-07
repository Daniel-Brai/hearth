defmodule Hearth.Repo.Migrations.CreateCommunitiesRoomGroupsTable do
  use Hearth.Repo.Migration

  @prefix :communities
  @table :room_groups

  # A new table is empty, so its references and indexes lock nothing anyone is reading
  # excellent_migrations:safety-assured-for-this-file column_reference_added index_not_concurrently

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :community_id, references(:communities, type: :uuid, on_delete: :delete_all),
        null: false

      add :name, :text, null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create index(@table, [:community_id, :position], prefix: @prefix)
  end
end
