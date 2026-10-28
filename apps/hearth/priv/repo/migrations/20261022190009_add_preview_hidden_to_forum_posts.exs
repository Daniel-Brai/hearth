defmodule Hearth.Repo.Migrations.AddPreviewHiddenToForumPosts do
  use Ecto.Migration

  @prefix :forum
  @table :posts

  # The author or a moderator took the link preview off
  def change do
    alter table(@table, prefix: @prefix) do
      add :preview_hidden_at, :timestamptz, null: true
    end
  end
end
