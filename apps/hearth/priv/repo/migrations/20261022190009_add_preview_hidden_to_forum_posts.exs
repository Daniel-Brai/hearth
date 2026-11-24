defmodule Hearth.Repo.Migrations.AddPreviewHiddenToForumPosts do
  use Ecto.Migration

  @prefix :forum
  @table :posts

  def change do
    alter table(@table, prefix: @prefix) do
      add :preview_hidden_at, :timestamptz, null: true
    end
  end
end
