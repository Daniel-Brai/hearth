defmodule Hearth.Repo.Migrations.CreateForumSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS forum"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS forum"
  end
end
