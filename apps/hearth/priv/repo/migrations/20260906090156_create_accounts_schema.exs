defmodule Hearth.Repo.Migrations.CreateAccountsSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS accounts"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS accounts"
  end
end
