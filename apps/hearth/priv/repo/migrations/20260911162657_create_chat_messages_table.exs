defmodule Hearth.Repo.Migrations.CreateChatMessagesTable do
  use Ecto.Migration

  @prefix :chat
  @table :messages

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :room_id,
          references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: true

      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all),
        null: true

      add :author_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :reply_to_id, references(:messages, type: :uuid, on_delete: :delete_all), null: true
      add :thread_root_id, references(:messages, type: :uuid, on_delete: :delete_all), null: true
      add :body, :text, null: false
      add :depth, :integer, null: false, default: 0
      add :path, {:array, :uuid}, null: false, default: []
      add :child_count, :integer, null: false, default: 0
      add :descendant_count, :integer, null: false, default: 0
      add :recent_repliers, {:array, :uuid}, null: false, default: []
      add :status, :string, null: false, default: "published"
      add :edited_at, :timestamptz, null: true
      add :deleted_at, :timestamptz, null: true

      timestamps()
    end

    create constraint(@table, :one_place,
             check: "num_nonnulls(room_id, conversation_id) = 1",
             prefix: @prefix
           )

    create constraint(@table, :depth_range, check: "depth BETWEEN 0 AND 10", prefix: @prefix)

    create index(@table, [:room_id, :inserted_at],
             prefix: @prefix,
             where: "reply_to_id IS NULL",
             name: :messages_room_top_index
           )

    create index(@table, [:conversation_id, :inserted_at],
             prefix: @prefix,
             where: "reply_to_id IS NULL",
             name: :messages_conversation_top_index
           )

    create index(@table, [:reply_to_id, :inserted_at], prefix: @prefix)
    create index(@table, :thread_root_id, prefix: @prefix)
    create index(@table, :path, prefix: @prefix, using: :gin)

    # A message answers one in the same room or conversation
    execute(
      """
      CREATE FUNCTION chat.message_parent_same_place() RETURNS trigger AS $$
      BEGIN
        IF NEW.reply_to_id IS NOT NULL AND NOT EXISTS (
          SELECT 1 FROM chat.messages
          WHERE id = NEW.reply_to_id
            AND room_id IS NOT DISTINCT FROM NEW.room_id
            AND conversation_id IS NOT DISTINCT FROM NEW.conversation_id
        ) THEN
          RAISE EXCEPTION 'a message can only answer one in the same place'
            USING ERRCODE = 'check_violation', CONSTRAINT = 'parent_same_place';
        END IF;
        RETURN NEW;
      END
      $$ LANGUAGE plpgsql
      """,
      "DROP FUNCTION chat.message_parent_same_place()"
    )

    execute(
      """
      CREATE TRIGGER messages_parent_same_place
      BEFORE INSERT OR UPDATE OF reply_to_id ON chat.messages
      FOR EACH ROW EXECUTE FUNCTION chat.message_parent_same_place()
      """,
      "DROP TRIGGER messages_parent_same_place ON chat.messages"
    )

    alter table(:conversation_members, prefix: @prefix) do
      modify :last_read_message_id,
             references(:messages, type: :uuid, on_delete: :nilify_all),
             from: :uuid
    end
  end
end
