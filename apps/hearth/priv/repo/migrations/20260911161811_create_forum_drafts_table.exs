defmodule Hearth.Repo.Migrations.CreateForumDraftsTable do
  use Ecto.Migration

  @prefix :forum
  @table :drafts

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: false

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :kind_id, references(:post_kinds, type: :uuid, on_delete: :nilify_all), null: true
      add :title, :string, null: true
      add :body, :text, null: true

      timestamps()
    end

    create unique_index(@table, [:user_id, :community_id], prefix: @prefix)
  end
end
