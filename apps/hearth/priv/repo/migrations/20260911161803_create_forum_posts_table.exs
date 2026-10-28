defmodule Hearth.Repo.Migrations.CreateForumPostsTable do
  use Ecto.Migration

  @prefix :forum
  @table :posts

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :kind_id, references(:post_kinds, type: :uuid, on_delete: :restrict), null: false

      add :author_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :title, :string, null: false
      add :body, :text, null: false, default: ""
      add :status, :string, null: false, default: "published"
      add :pinned_at, :timestamptz, null: true
      add :locked_at, :timestamptz, null: true
      # Points at a reply and its foreign key is added with the replies table
      add :answer_reply_id, :uuid, null: true
      add :reply_count, :integer, null: false, default: 0
      add :helpful_count, :integer, null: false, default: 0
      add :last_activity_at, :timestamptz, null: false
      add :edited_at, :timestamptz, null: true
      add :deleted_at, :timestamptz, null: true
      # Where the post came from and Chat and Voice add the foreign keys
      add :source_message_id, :uuid, null: true
      add :source_session_id, :uuid, null: true

      timestamps()
    end

    execute(
      """
      ALTER TABLE forum.posts ADD COLUMN search tsvector
        GENERATED ALWAYS AS (
          setweight(to_tsvector('simple', coalesce(title, '')), 'A') ||
          setweight(to_tsvector('simple', coalesce(body, '')), 'B')
        ) STORED
      """,
      "ALTER TABLE forum.posts DROP COLUMN search"
    )

    create index(@table, [:community_id, :last_activity_at], prefix: @prefix)
    create index(@table, :kind_id, prefix: @prefix)
    create index(@table, :author_id, prefix: @prefix)
    create index(@table, :search, prefix: @prefix, using: :gin)
  end
end
