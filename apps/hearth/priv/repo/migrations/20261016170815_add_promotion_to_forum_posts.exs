defmodule Hearth.Repo.Migrations.AddPromotionToForumPosts do
  use Ecto.Migration

  @prefix :forum
  @table :posts

  def change do
    alter table(@table, prefix: @prefix) do
      add :source_room_id,
          references(:rooms, type: :uuid, prefix: :communities, on_delete: :nilify_all),
          null: true

      add :source_message_count, :integer, null: true

      add :promoted_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true
    end
  end
end
