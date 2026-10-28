defmodule Hearth.Repo.Migrations.CreateChatRoomReadsTable do
  use Ecto.Migration

  @prefix :chat
  @table :room_reads

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      add :room_id,
          references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
          primary_key: true

      add :last_read_message_id, references(:messages, type: :uuid, on_delete: :nilify_all),
        null: true

      timestamps()
    end
  end
end
