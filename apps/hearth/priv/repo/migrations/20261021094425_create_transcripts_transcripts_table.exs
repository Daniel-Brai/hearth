defmodule Hearth.Repo.Migrations.CreateTranscriptsTranscriptsTable do
  # One transcript per recording, so a second run of the job finds the first

  use Ecto.Migration

  @prefix :transcripts
  @table :transcripts

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :recording_id,
          references(:recordings, type: :uuid, prefix: :voice, on_delete: :delete_all),
          null: false

      add :session_id,
          references(:sessions, type: :uuid, prefix: :voice, on_delete: :delete_all),
          null: false

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :post_id, references(:posts, type: :uuid, prefix: :forum, on_delete: :nilify_all),
        null: true

      add :status, :string, null: false
      add :failure, :string, null: true
      add :language, :string, null: true
      add :engine, :string, null: false
      add :model_versions, :map, null: false, default: %{}
      add :duration_ms, :integer, null: true
      add :ready_at, :timestamptz, null: true

      timestamps()
    end

    create constraint(@table, :status,
             check: "status IN ('queued', 'transcribing', 'ready', 'failed')",
             prefix: @prefix
           )

    create unique_index(@table, [:recording_id], prefix: @prefix)
    create index(@table, [:session_id], prefix: @prefix)
    create index(@table, [:post_id], prefix: @prefix)
  end
end
