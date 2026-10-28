defmodule Hearth.Repo.Migrations.CreateRateLimitSchema do
  use Ecto.Migration

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS rate_limit"
  end

  def down do
    execute "DROP SCHEMA IF EXISTS rate_limit"
  end
end
