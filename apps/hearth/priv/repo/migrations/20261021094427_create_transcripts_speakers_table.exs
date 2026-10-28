defmodule Hearth.Repo.Migrations.CreateTranscriptsSpeakersTable do
  use Ecto.Migration

  @prefix :transcripts
  @table :speakers

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :transcript_id, references(:transcripts, type: :uuid, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
        null: true

      add :speaker_index, :integer, null: false
      add :label, :string, null: true
      add :transcribed_at, :timestamptz, null: true

      timestamps()
    end

    create unique_index(@table, [:transcript_id, :speaker_index], prefix: @prefix)
  end
end
