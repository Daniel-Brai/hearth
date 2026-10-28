defmodule Hearth.Repo.Migrations.CreateForumPostKindsTable do
  use Ecto.Migration

  @prefix :forum
  @table :post_kinds

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :key, :string, null: false
      add :label, :string, null: false
      add :icon, :string, null: false
      add :hue, :string, null: false
      add :description, :string, null: true
      add :title_hint, :string, null: true
      add :body_hint, :string, null: true
      add :answers, :boolean, null: false, default: false
      add :postable, :boolean, null: false, default: true
      add :position, :integer, null: false, default: 0

      timestamps()
    end

    create unique_index(@table, [:community_id, :key], prefix: @prefix)
  end
end
