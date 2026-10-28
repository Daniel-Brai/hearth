defmodule Hearth.Repo.Migrations.IndexNotificationsReadAt do
  use Ecto.Migration

  @prefix :notifications
  @table :notifications

  # Old read notifications are pruned by when they were read
  def change do
    create index(@table, [:read_at], prefix: @prefix, where: "read_at IS NOT NULL")
  end
end
