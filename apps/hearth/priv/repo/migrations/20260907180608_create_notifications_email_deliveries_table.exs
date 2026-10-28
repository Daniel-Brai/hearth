defmodule Hearth.Repo.Migrations.CreateNotificationsEmailDeliveriesTable do
  use Ecto.Migration

  @prefix :notifications
  @table :email_deliveries

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
        null: true

      add :template, :string, null: false
      add :to, :citext, null: false
      add :provider_message_id, :string, null: true
      add :status, :string, null: false
      add :error, :text, null: true

      timestamps()
    end

    create index(@table, :user_id, prefix: @prefix)
    create index(@table, :to, prefix: @prefix)
    create index(@table, :provider_message_id, prefix: @prefix)
  end
end
