defmodule Hearth.Repo.Migrations.CreateInstanceReleaseChecksTable do
  use Ecto.Migration

  @prefix :instance

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS instance"

    create table(:release_checks, prefix: @prefix, primary_key: false) do
      add :id, :integer, primary_key: true
      add :latest_version, :string
      add :release_name, :string
      add :release_url, :text
      add :notes, :text
      add :published_at, :utc_datetime_usec
      add :checked_at, :utc_datetime_usec, null: false
    end

    create constraint(:release_checks, :single_row, check: "id = 1", prefix: @prefix)
  end

  def down do
    drop table(:release_checks, prefix: @prefix)
    execute "DROP SCHEMA IF EXISTS instance"
  end
end
