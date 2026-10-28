defmodule Hearth.Repo.Migrations.AddTitleToVoiceRecordings do
  use Ecto.Migration

  @prefix :voice
  @table :recordings

  # Taken from the event on when recording starts, and the recorder can rename it
  def change do
    alter table(@table, prefix: @prefix) do
      add :title, :text, null: true
    end
  end
end
