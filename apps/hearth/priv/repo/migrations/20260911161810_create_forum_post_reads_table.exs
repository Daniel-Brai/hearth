defmodule Hearth.Repo.Migrations.CreateForumPostReadsTable do
  use Ecto.Migration

  @prefix :forum
  @table :post_reads

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), primary_key: true
      add :last_seen_at, :timestamptz, null: false
      add :seen_reply_count, :integer, null: false, default: 0
    end

    create index(@table, :post_id, prefix: @prefix)
  end
end
