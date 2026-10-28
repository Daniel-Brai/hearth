defmodule Hearth.Repo.Migrations.CreateEventsInterestsTable do
  use Ecto.Migration

  @prefix :events
  @table :event_interests

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :event_id, references(:events, type: :uuid, on_delete: :delete_all), primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      add :reminded_at, :timestamptz, null: true

      timestamps()
    end

    create index(@table, :user_id, prefix: @prefix)
  end
end
