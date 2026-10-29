defmodule Hearth.Repo.Migrations.CreateCommunitiesRoomRoles do
  use Ecto.Migration

  @prefix :communities
  @table :room_roles

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :room_id, references(:rooms, type: :uuid, on_delete: :delete_all), primary_key: true

      add :role_id,
          references(:roles, type: :uuid, prefix: :iam, on_delete: :delete_all),
          primary_key: true
    end

    create index(@table, :role_id, prefix: @prefix)
  end
end
