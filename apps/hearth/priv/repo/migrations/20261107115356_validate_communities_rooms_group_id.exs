defmodule Hearth.Repo.Migrations.ValidateCommunitiesRoomsGroupId do
  use Hearth.Repo.Migration

  # Validating takes a lock that still lets rooms be read and written
  # excellent_migrations:safety-assured-for-this-file raw_sql_executed
  def up do
    execute "ALTER TABLE communities.rooms VALIDATE CONSTRAINT rooms_group_id_fkey"
  end

  def down, do: :ok
end
