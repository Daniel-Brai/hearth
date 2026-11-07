defmodule Hearth.Repo.Migrations.CreateForumBookmarksTable do
  use Hearth.Repo.Migration

  @prefix :forum
  @table :bookmarks

  # A new table is empty, so its references and indexes lock nothing anyone is reading
  # excellent_migrations:safety-assured-for-this-file column_reference_added index_not_concurrently

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), primary_key: true

      timestamps(updated_at: false)
    end

    create index(@table, [:user_id, :inserted_at], prefix: @prefix)
  end
end
