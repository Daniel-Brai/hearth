defmodule Hearth.Repo.Migrations.CreateCommunitiesCommunityCategories do
  use Ecto.Migration

  @prefix :communities
  @table :community_categories

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :community_id, references(:communities, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :category_id, references(:categories, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :position, :integer, null: false, default: 0
    end

    create index(@table, :category_id, prefix: @prefix)
  end
end
