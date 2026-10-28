defmodule Hearth.Repo.Migrations.CreateForumRepliesTable do
  use Ecto.Migration

  @prefix :forum
  @table :replies

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), null: false

      add :author_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :parent_reply_id, references(:replies, type: :uuid, on_delete: :delete_all), null: true
      add :root_reply_id, references(:replies, type: :uuid, on_delete: :delete_all), null: true
      add :body, :text, null: false
      add :depth, :integer, null: false, default: 0
      add :path, {:array, :uuid}, null: false, default: []
      add :child_count, :integer, null: false, default: 0
      add :descendant_count, :integer, null: false, default: 0
      add :recent_repliers, {:array, :uuid}, null: false, default: []
      add :helpful_count, :integer, null: false, default: 0
      add :status, :string, null: false, default: "published"
      add :edited_at, :timestamptz, null: true
      add :deleted_at, :timestamptz, null: true

      timestamps()
    end

    create constraint(@table, :depth_range, check: "depth BETWEEN 0 AND 10", prefix: @prefix)

    create index(@table, [:post_id, "helpful_count DESC", :inserted_at],
             prefix: @prefix,
             where: "parent_reply_id IS NULL",
             name: :replies_top_helpful_index
           )

    create index(@table, [:post_id, :inserted_at],
             prefix: @prefix,
             where: "parent_reply_id IS NULL",
             name: :replies_top_newest_index
           )

    create index(@table, [:parent_reply_id, :inserted_at], prefix: @prefix)
    create index(@table, :root_reply_id, prefix: @prefix)
    create index(@table, :path, prefix: @prefix, using: :gin)

    # A reply's parent must be a reply on the same post
    execute(
      """
      CREATE FUNCTION forum.reply_parent_same_post() RETURNS trigger AS $$
      BEGIN
        IF NEW.parent_reply_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM forum.replies WHERE id = NEW.parent_reply_id AND post_id = NEW.post_id
        ) THEN
          RAISE EXCEPTION 'a reply''s parent must be on the same post'
            USING ERRCODE = 'check_violation', CONSTRAINT = 'parent_same_post';
        END IF;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql
      """,
      "DROP FUNCTION forum.reply_parent_same_post()"
    )

    execute(
      """
      CREATE TRIGGER replies_parent_same_post
      BEFORE INSERT OR UPDATE OF parent_reply_id ON forum.replies
      FOR EACH ROW EXECUTE FUNCTION forum.reply_parent_same_post()
      """,
      "DROP TRIGGER replies_parent_same_post ON forum.replies"
    )

    alter table(:posts, prefix: @prefix) do
      modify :answer_reply_id, references(:replies, type: :uuid, on_delete: :nilify_all),
        from: :uuid
    end
  end
end
