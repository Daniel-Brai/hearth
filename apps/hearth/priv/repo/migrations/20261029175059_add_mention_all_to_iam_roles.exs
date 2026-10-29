defmodule Hearth.Repo.Migrations.AddMentionAllToIamRoles do
  use Ecto.Migration

  # Communities made before @all get it on their Owner and Moderator roles
  def up do
    execute """
    UPDATE iam.roles
    SET permissions = array_append(permissions, 'mention.all')
    WHERE key IN ('owner', 'moderator') AND NOT ('mention.all' = ANY(permissions))
    """
  end

  def down do
    execute """
    UPDATE iam.roles SET permissions = array_remove(permissions, 'mention.all')
    WHERE key IN ('owner', 'moderator')
    """
  end
end
