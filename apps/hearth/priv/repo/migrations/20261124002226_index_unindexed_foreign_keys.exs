defmodule Hearth.Repo.Migrations.IndexUnindexedForeignKeys do
  use Hearth.Repo.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Deleting a kind or a community scans these tables for rows that point at it
  def change do
    create index(:drafts, [:kind_id], prefix: :forum, concurrently: true)

    create index(:community_requests, [:community_id],
             prefix: :communities,
             concurrently: true
           )
  end
end
