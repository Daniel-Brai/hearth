defmodule Hearth.Repo.Migrations.CreateCommunitiesRequestsTable do
  use Ecto.Migration

  @prefix :communities
  @table :community_requests

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :requester_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
          null: false

      add :decided_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :community_id, references(:communities, type: :uuid, on_delete: :nilify_all), null: true

      add :name, :string, null: false
      add :tagline, :string, null: true
      add :hue, :integer, null: false, default: 30
      add :visibility, :string, null: false, default: "public"
      add :template, :string, null: false, default: "blank"
      add :note, :text, null: true
      add :status, :string, null: false, default: "pending"
      add :decided_at, :timestamptz, null: true

      timestamps()
    end

    create index(@table, :status, prefix: @prefix)
    create index(@table, :requester_id, prefix: @prefix)
  end
end
