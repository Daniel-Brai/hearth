defmodule Hearth.Repo.Migrations.CreateAccountsUsersTable do
  use Ecto.Migration

  @prefix :accounts
  @table :users

  def up do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :username, :citext, null: false
      add :display_name, :string, null: true
      add :email, :citext, null: false
      add :email_confirmed_at, :timestamptz, null: true
      add :password_hash, :string, null: true
      add :avatar_id, :uuid, null: true
      add :bio, :text, null: true
      add :pronouns, :string, null: true
      add :location, :string, null: true
      add :timezone, :string, null: true
      add :locale, :string, null: true
      add :last_seen_at, :timestamptz, null: true
      add :is_instance_admin, :boolean, null: false, default: false
      add :deleted_at, :timestamptz, null: true
      add :links, {:array, :map}, null: false, default: []
      add :settings, :map, null: false, default: %{}
      add :privacy, :map, null: false, default: %{}

      timestamps()
    end

    create unique_index(@table, :username, prefix: @prefix)
    create unique_index(@table, :email, prefix: @prefix)

    # Usernames are permanent since mentions, links, bans and logs name people by them
    execute """
    CREATE FUNCTION accounts.keep_username() RETURNS trigger AS $$
    BEGIN
      IF NEW.username IS DISTINCT FROM OLD.username THEN
        RAISE EXCEPTION 'usernames cannot be changed'
          USING ERRCODE = 'check_violation', CONSTRAINT = 'username_unchanged';
      END IF;
      RETURN NEW;
    END
    $$ LANGUAGE plpgsql
    """

    execute """
    CREATE TRIGGER users_keep_username
    BEFORE UPDATE OF username ON accounts.users
    FOR EACH ROW EXECUTE FUNCTION accounts.keep_username()
    """
  end

  def down do
    drop table(@table, prefix: @prefix)
    execute "DROP FUNCTION accounts.keep_username()"
  end
end
