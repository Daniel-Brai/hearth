defmodule Hearth.Repo.Migrations.CreateTranscriptsSegmentsTable do
  use Ecto.Migration

  @prefix :transcripts
  @table :segments

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :transcript_id, references(:transcripts, type: :uuid, on_delete: :delete_all),
        null: false

      add :speaker_id, references(:speakers, type: :uuid, on_delete: :delete_all), null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :text, :text, null: false
      add :words, {:array, :map}, null: true

      add :edited_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :edited_at, :timestamptz, null: true

      timestamps()
    end

    create index(@table, [:transcript_id, :start_ms], prefix: @prefix)
    create index(@table, [:speaker_id], prefix: @prefix)
  end
end
