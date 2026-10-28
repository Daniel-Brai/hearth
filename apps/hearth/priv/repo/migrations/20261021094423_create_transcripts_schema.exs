defmodule Hearth.Repo.Migrations.CreateTranscriptsSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS transcripts"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS transcripts"
  end
end
