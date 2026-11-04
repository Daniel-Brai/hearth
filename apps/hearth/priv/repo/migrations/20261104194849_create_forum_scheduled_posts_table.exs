defmodule Hearth.Repo.Migrations.CreateForumScheduledPostsTable do
  use Hearth.Repo.Migration

  @prefix :forum
  @table :scheduled_posts

  # A post waits here until its time, and a published one is deleted
  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :author_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
          null: false

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :kind_id, references(:post_kinds, type: :uuid, on_delete: :nilify_all), null: true
      add :title, :text, null: false
      add :body, :text, null: false, default: ""
      add :attachment_ids, {:array, :uuid}, null: false, default: []
      add :send_at, :timestamptz, null: false
      add :failure, :text, null: true

      timestamps()
    end

    create index(@table, [:author_id, :send_at], prefix: @prefix)
    create index(@table, [:community_id], prefix: @prefix)
    create index(@table, [:kind_id], prefix: @prefix)
  end
end
