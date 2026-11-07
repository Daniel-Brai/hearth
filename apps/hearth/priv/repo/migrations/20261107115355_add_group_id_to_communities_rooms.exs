defmodule Hearth.Repo.Migrations.AddGroupIdToCommunitiesRooms do
  use Hearth.Repo.Migration

  @prefix :communities
  @table :rooms

  # Unvalidated so adding it never scans rooms under a lock. The next migration validates it
  def change do
    alter table(@table, prefix: @prefix) do
      add :group_id,
          references(:room_groups, type: :uuid, on_delete: :nilify_all, validate: false),
          null: true
    end
  end
end
