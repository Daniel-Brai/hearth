defmodule Hearth.Repo.Migrations.AddIamCommunityForeignKeys do
  use Ecto.Migration

  @prefix :iam

  def change do
    for table <- [:roles, :memberships] do
      alter table(table, prefix: @prefix) do
        modify :community_id,
               references(:communities,
                 type: :uuid,
                 prefix: :communities,
                 on_delete: :delete_all
               ),
               from: :uuid
      end
    end
  end
end
