defmodule Hearth.Repo.Migrations.CreateChatSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS chat"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS chat"
  end
end
