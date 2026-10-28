defmodule Hearth.Repo.Migrations.CreateCommunitiesRoomsTable do
  use Ecto.Migration

  @prefix :communities
  @table :rooms

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :community_id, references(:communities, type: :uuid, on_delete: :delete_all),
        null: false

      add :type, :string, null: false, default: "text"
      add :slug, :string, null: false
      add :name, :string, null: false
      add :topic, :string, null: true
      add :position, :integer, null: false, default: 0
      add :moderation, :string, null: true
      add :settings, :map, null: false, default: %{}
      add :archived_at, :timestamptz, null: true

      timestamps()
    end

    create unique_index(@table, [:community_id, :slug], prefix: @prefix)
  end
end
