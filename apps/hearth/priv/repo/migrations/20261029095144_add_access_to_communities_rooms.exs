defmodule Hearth.Repo.Migrations.AddAccessToCommunitiesRooms do
  use Ecto.Migration

  @prefix :communities
  @table :rooms

  def change do
    alter table(@table, prefix: @prefix) do
      add :access, :string, null: false, default: "everyone"
    end
  end
end
