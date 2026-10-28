defmodule Hearth.Repo.Migrations.CreateTranscriptsAudioMarksTable do
  use Ecto.Migration

  @prefix :transcripts
  @table :audio_marks

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :transcript_id, references(:transcripts, type: :uuid, on_delete: :delete_all),
        null: false

      add :recording_id,
          references(:recordings, type: :uuid, prefix: :voice, on_delete: :delete_all),
          null: false

      add :kind, :string, null: false
      add :start_ms, :integer, null: false
      add :end_ms, :integer, null: false
      add :label, :string, null: true
      add :removed, :boolean, null: false, default: false

      timestamps()
    end

    create constraint(@table, :kind, check: "kind IN ('silence', 'filler')", prefix: @prefix)
    create index(@table, [:transcript_id, :start_ms], prefix: @prefix)
  end
end
