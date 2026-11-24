defmodule Hearth.Repo.Migrations.WidenForumPostKindsHints do
  use Hearth.Repo.Migration

  @prefix :forum
  @table :post_kinds

  # varchar to text only changes the catalog in Postgres, so the table isn't rewritten or locked for long
  # excellent_migrations:safety-assured-for-this-file column_type_changed

  def change do
    alter table(@table, prefix: @prefix) do
      modify :description, :text, from: :string
      modify :body_hint, :text, from: :string
    end
  end
end
