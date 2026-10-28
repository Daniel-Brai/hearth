defmodule Hearth.Repo.Migrations.CreateMediaSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS media"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS media"
  end
end
