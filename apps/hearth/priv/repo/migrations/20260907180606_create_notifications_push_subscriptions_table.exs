defmodule Hearth.Repo.Migrations.CreateNotificationsPushSubscriptionsTable do
  use Ecto.Migration

  @prefix :notifications
  @table :push_subscriptions

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: false

      add :endpoint, :text, null: false
      add :p256dh, :string, null: false
      add :auth, :string, null: false
      add :user_agent, :text, null: true
      add :last_used_at, :timestamptz, null: true

      timestamps()
    end

    create unique_index(@table, :endpoint, prefix: @prefix)
    create index(@table, :user_id, prefix: @prefix)
  end
end
