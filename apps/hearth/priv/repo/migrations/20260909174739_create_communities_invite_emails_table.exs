defmodule Hearth.Repo.Migrations.CreateCommunitiesInviteEmailsTable do
  use Ecto.Migration

  @prefix :communities
  @table :invite_emails

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :invite_id, references(:invites, type: :uuid, on_delete: :delete_all), null: false
      add :email, :citext, null: false
      add :status, :string, null: false, default: "pending"
      add :sent_at, :timestamptz, null: true
      add :accepted_at, :timestamptz, null: true

      timestamps()
    end

    create unique_index(@table, [:invite_id, :email], prefix: @prefix)
  end
end
