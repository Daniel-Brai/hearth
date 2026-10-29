defmodule Hearth.Repo.Migrations.DropPreviewHiddenAtFromForumPosts do
  use Ecto.Migration

  @prefix :forum
  @table :posts

  def change do
    alter table(@table, prefix: @prefix) do
      remove :preview_hidden_at, :utc_datetime_usec
    end
  end
end
