defmodule Hearth.Repo.Migrations.CreateChatPollsTable do
  use Hearth.Repo.Migration

  @prefix :chat
  @table :polls

  # A poll is a room message, so deleting the message takes the poll with it
  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :message_id, references(:messages, type: :uuid, on_delete: :delete_all), null: false

      add :room_id,
          references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :multiple, :boolean, null: false, default: false
      add :closes_at, :timestamptz, null: true
      add :closed_at, :timestamptz, null: true

      timestamps()
    end

    create unique_index(@table, [:message_id], prefix: @prefix)
    create index(@table, [:room_id], prefix: @prefix)
  end
end
