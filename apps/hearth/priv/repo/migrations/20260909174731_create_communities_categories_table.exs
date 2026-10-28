defmodule Hearth.Repo.Migrations.CreateCommunitiesCategoriesTable do
  use Ecto.Migration

  @prefix :communities
  @table :categories

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :slug, :string, null: false
      add :name, :string, null: false
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(@table, :slug, prefix: @prefix)
  end
end
