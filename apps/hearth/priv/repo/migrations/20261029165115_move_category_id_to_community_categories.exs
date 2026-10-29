defmodule Hearth.Repo.Migrations.MoveCategoryIdToCommunityCategories do
  use Ecto.Migration

  @prefix :communities
  @table :communities

  def up do
    execute """
    INSERT INTO communities.community_categories (community_id, category_id, position)
    SELECT id, category_id, 0 FROM communities.communities WHERE category_id IS NOT NULL
    """

    alter table(@table, prefix: @prefix) do
      remove :category_id
    end
  end

  # Only the first category fits back into the single column
  def down do
    alter table(@table, prefix: @prefix) do
      add :category_id, references(:categories, type: :uuid, on_delete: :nilify_all)
    end

    create index(@table, :category_id, prefix: @prefix)

    execute """
    UPDATE communities.communities c SET category_id = cc.category_id
    FROM communities.community_categories cc
    WHERE cc.community_id = c.id AND cc.position = 0
    """
  end
end
