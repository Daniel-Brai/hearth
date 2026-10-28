defmodule Hearth.Repo.Migrations.CreateNotificationsNotificationsTable do
  use Ecto.Migration

  @prefix :notifications
  @table :notifications

  # The subject has no foreign key so the history survives its deletion
  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: false

      add :actor_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all)
      add :community_id, :uuid
      add :kind, :text, null: false
      add :subject_type, :text, null: false
      add :subject_id, :uuid, null: false
      add :data, :map, null: false, default: %{}
      add :read_at, :timestamptz

      timestamps()
    end

    create index(@table, [:user_id, :inserted_at], prefix: @prefix)

    create index(@table, [:user_id],
             prefix: @prefix,
             where: "read_at IS NULL",
             name: :notifications_unread_index
           )

    create constraint(@table, :kind,
             check:
               "kind IN ('reply', 'mention', 'dm', 'answer', 'event_reminder', 'live_started', 'invite')",
             prefix: @prefix
           )
  end
end
