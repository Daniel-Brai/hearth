defmodule Hearth.Repo.Migrations.CreateIamSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS iam"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS iam"
  end
end
