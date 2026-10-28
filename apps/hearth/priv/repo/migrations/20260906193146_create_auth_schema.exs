defmodule Hearth.Repo.Migrations.CreateAuthSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS auth"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS auth"
  end
end
