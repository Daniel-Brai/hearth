defmodule Hearth.Repo.Migrations.CreateCommunitiesInstanceSettingsTable do
  use Ecto.Migration

  @prefix :communities
  @table :instance_settings

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :integer, primary_key: true, default: 1
      add :creation, :text, null: false

      timestamps()
    end

    create constraint(@table, :one_row, check: "id = 1", prefix: @prefix)

    create constraint(@table, :creation,
             check: "creation IN ('admins', 'request', 'anyone')",
             prefix: @prefix
           )
  end
end
