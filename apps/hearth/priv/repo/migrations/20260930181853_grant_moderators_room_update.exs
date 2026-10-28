defmodule Hearth.Repo.Migrations.GrantModeratorsRoomUpdate do
  use Ecto.Migration

  # Moderators now look after rooms too so communities made before get it
  def up do
    execute """
    UPDATE iam.roles
    SET permissions = array_append(permissions, 'room.update')
    WHERE key = 'moderator' AND NOT ('room.update' = ANY(permissions))
    """
  end

  def down do
    execute """
    UPDATE iam.roles SET permissions = array_remove(permissions, 'room.update')
    WHERE key = 'moderator'
    """
  end
end
