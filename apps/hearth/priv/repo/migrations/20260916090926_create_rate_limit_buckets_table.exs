defmodule Hearth.Repo.Migrations.CreateRateLimitBucketsTable do
  use Ecto.Migration

  @prefix :rate_limit
  @table :buckets

  # Buckets are rewritten on every hit and are cheap to lose so the table
  # skips the write-ahead log
  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :key, :text, primary_key: true
      add :tokens, :float, null: false
      add :allowed, :boolean, null: false
      add :refilled_at, :timestamptz, null: false
      add :expires_at, :timestamptz, null: false
    end

    execute "ALTER TABLE rate_limit.buckets SET UNLOGGED",
            "ALTER TABLE rate_limit.buckets SET LOGGED"

    create index(@table, [:expires_at], prefix: @prefix)
  end
end
