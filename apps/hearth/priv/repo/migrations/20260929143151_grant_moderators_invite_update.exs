defmodule Hearth.Repo.Migrations.GrantModeratorsInviteUpdate do
  use Ecto.Migration

  # invite.update split off invite.create and moderators always could
  # manage invites so older communities keep that
  def up do
    execute """
    UPDATE iam.roles
    SET permissions = array_append(permissions, 'invite.update')
    WHERE key = 'moderator' AND NOT ('invite.update' = ANY(permissions))
    """
  end

  def down do
    execute "UPDATE iam.roles SET permissions = array_remove(permissions, 'invite.update')"
  end
end
