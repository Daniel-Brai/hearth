defmodule Hearth.Repo.Migrations.CreateChatScheduledMessagesTable do
  use Hearth.Repo.Migration

  @prefix :chat
  @table :scheduled_messages

  # A message waits here until its time, and a sent one is deleted
  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :author_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
          null: false

      add :room_id,
          references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: true

      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all),
        null: true

      add :body, :binary, null: false
      add :attachment_ids, {:array, :uuid}, null: false, default: []
      add :send_at, :timestamptz, null: false
      add :failure, :text, null: true

      timestamps()
    end

    create constraint(@table, :one_place,
             check: "num_nonnulls(room_id, conversation_id) = 1",
             prefix: @prefix
           )

    create index(@table, [:author_id, :send_at], prefix: @prefix)
    create index(@table, [:room_id], prefix: @prefix)
    create index(@table, [:conversation_id], prefix: @prefix)
  end
end
