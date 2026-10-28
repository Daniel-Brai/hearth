defmodule Hearth.Repo.Migrations.CreateCommunitiesSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS communities"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS communities"
  end
end
