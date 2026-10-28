defmodule Hearth.Repo.Migrations.AddDescriptionToCommunityRequests do
  use Ecto.Migration

  @prefix :communities
  @table :community_requests

  def change do
    alter table(@table, prefix: @prefix) do
      add :description, :text, null: true
    end
  end
end
