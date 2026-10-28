defmodule Hearth.Repo.Migrations.CreateForumTagsTable do
  use Ecto.Migration

  @prefix :forum

  def change do
    create table(:tags, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :name, :citext, null: false

      timestamps()
    end

    create unique_index(:tags, [:community_id, :name], prefix: @prefix)

    create table(:post_tags, prefix: @prefix, primary_key: false) do
      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), primary_key: true
      add :tag_id, references(:tags, type: :uuid, on_delete: :delete_all), primary_key: true
    end

    create index(:post_tags, :tag_id, prefix: @prefix)
  end
end
