defmodule Hearth.Repo.Migrations.AddForumRepliesSearchIndex do
  use Hearth.Repo.Migration

  @disable_ddl_transaction true

  # The repo migrates under pg_advisory_lock so a concurrent build never waits on a migrations table lock
  # excellent_migrations:safety-assured-for-this-file index_concurrently_without_disable_migration_lock

  @prefix :forum
  @table :replies

  # An index on the expression rather than a stored column so replies are never rewritten
  # Post.search/3 must use the same expression to hit it
  def change do
    create index(@table, ["to_tsvector('simple', body)"],
             name: :replies_search_index,
             prefix: @prefix,
             using: :gin,
             concurrently: true
           )
  end
end
