defmodule Hearth.Repo.Migrations.CreateCommunitiesCommunitiesTable do
  use Ecto.Migration

  @prefix :communities
  @table :communities

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :category_id, references(:categories, type: :uuid, on_delete: :nilify_all), null: true

      add :creator_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
        null: true

      add :owner_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :restrict),
        null: false

      add :slug, :citext, null: false
      add :name, :string, null: false
      add :tagline, :string, null: true
      add :description, :text, null: true
      add :hue, :integer, null: false, default: 30
      add :logo_id, :uuid, null: true
      add :banner_id, :uuid, null: true
      add :visibility, :string, null: false, default: "public"
      add :moderation, :string, null: false, default: "none"
      add :welcome_message, :text, null: true
      add :template, :string, null: false, default: "blank"
      add :links, {:array, :map}, null: false, default: []
      add :archived_at, :timestamptz, null: true

      timestamps()
    end

    create unique_index(@table, :slug, prefix: @prefix)
    create index(@table, :owner_id, prefix: @prefix)
    create index(@table, :category_id, prefix: @prefix)
  end
end
