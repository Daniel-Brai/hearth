defmodule Hearth.Repo.Migrations.CreateIamMembershipRolesTable do
  use Ecto.Migration

  @prefix :iam
  @table :membership_roles

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :membership_id, references(:memberships, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :role_id, references(:roles, type: :uuid, on_delete: :delete_all), primary_key: true
    end

    create index(@table, :role_id, prefix: @prefix)
  end
end
