defmodule Hearth.Repo.Migrations.AddAccountsUsersTrigramIndexes do
  use Ecto.Migration

  # Finding people by part of their username or name typos included stays
  # fast as the instance grows and the expressions match User.search/3
  def up do
    execute """
    CREATE INDEX users_username_trgm_index ON accounts.users
    USING gin (lower(username::text) gin_trgm_ops)
    """

    execute """
    CREATE INDEX users_display_name_trgm_index ON accounts.users
    USING gin (lower(display_name) gin_trgm_ops)
    """
  end

  def down do
    execute "DROP INDEX accounts.users_display_name_trgm_index"
    execute "DROP INDEX accounts.users_username_trgm_index"
  end
end
