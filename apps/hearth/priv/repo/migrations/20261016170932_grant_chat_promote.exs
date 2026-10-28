defmodule Hearth.Repo.Migrations.GrantChatPromote do
  use Ecto.Migration

  # Roles copy their permissions when a community starts so existing Owners and Moderators get it here
  def up do
    execute """
    UPDATE iam.roles SET permissions = array_append(permissions, 'chat.promote')
    WHERE key IN ('owner', 'moderator') AND NOT ('chat.promote' = ANY(permissions))
    """
  end

  def down do
    execute "UPDATE iam.roles SET permissions = array_remove(permissions, 'chat.promote')"
  end
end
