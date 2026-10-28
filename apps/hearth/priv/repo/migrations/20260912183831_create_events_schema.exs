defmodule Hearth.Repo.Migrations.CreateEventsSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS events"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS events"
  end
end
