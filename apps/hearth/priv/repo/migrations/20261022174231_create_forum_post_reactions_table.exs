defmodule Hearth.Repo.Migrations.CreateForumPostReactionsTable do
  use Ecto.Migration

  @prefix :forum
  @table :post_reactions

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      add :emoji, :string, primary_key: true

      timestamps(updated_at: false)
    end
  end
end
