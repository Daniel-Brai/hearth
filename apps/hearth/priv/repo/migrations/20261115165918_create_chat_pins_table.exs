defmodule Hearth.Repo.Migrations.CreateChatPinsTable do
  use Hearth.Repo.Migration

  @prefix :chat
  @table :pins

  # A new table is empty, so its references and indexes lock nothing anyone is reading
  # excellent_migrations:safety-assured-for-this-file column_reference_added index_not_concurrently

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :message_id, references(:messages, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :room_id,
          references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :pinned_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      timestamps(updated_at: false)
    end

    create index(@table, [:room_id, :inserted_at], prefix: @prefix)
  end
end
