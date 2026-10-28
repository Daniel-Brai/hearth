defmodule Hearth.Repo.Migrations.CreateForumPostWatchesTable do
  use Ecto.Migration

  @prefix :forum
  @table :post_watches

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), primary_key: true
      # False keeps someone's choice to stop watching when they reply again
      add :watching, :boolean, null: false

      timestamps()
    end

    create index(@table, :post_id, prefix: @prefix, where: "watching")
  end
end
