defmodule Hearth.Repo.Migrations.CreateEventsEventsTable do
  use Ecto.Migration

  @prefix :events
  @table :events

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :host_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
        null: true

      add :room_id,
          references(:rooms, type: :uuid, prefix: :communities, on_delete: :nilify_all),
          null: true

      add :title, :string, null: false
      add :description, :text, null: true
      add :starts_at, :timestamptz, null: false
      add :duration_min, :integer, null: false
      add :timezone, :string, null: false, default: "Etc/UTC"
      add :repeat, :string, null: false, default: "none"
      add :place, :string, null: false
      add :url, :text, null: true
      add :talk_mode, :string, null: true
      add :cancelled_at, :timestamptz, null: true

      timestamps()
    end

    create constraint(@table, :place_has_target,
             check:
               "(place = 'room' AND room_id IS NOT NULL) OR (place = 'link' AND url IS NOT NULL)",
             prefix: @prefix
           )

    create index(@table, [:community_id, :starts_at], prefix: @prefix)
    create index(@table, :host_id, prefix: @prefix)
  end
end
