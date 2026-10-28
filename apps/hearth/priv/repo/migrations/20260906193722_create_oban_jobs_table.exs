defmodule Hearth.Repo.Migrations.CreateObanJobsTable do
  use Ecto.Migration

  @prefix "oban"

  def up do
    Oban.Migration.up(version: 14, prefix: @prefix)
  end

  def down do
    Oban.Migration.down(version: 1, prefix: @prefix)
  end
end
