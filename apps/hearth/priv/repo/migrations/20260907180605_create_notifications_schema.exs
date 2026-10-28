defmodule Hearth.Repo.Migrations.CreateNotificationsSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS notifications"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS notifications"
  end
end
