defmodule Hearth.Repo.Migrations.CreateCommunitiesBansTable do
  use Ecto.Migration

  @prefix :communities
  @table :bans

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :community_id, references(:communities, type: :uuid, on_delete: :delete_all),
        null: false

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: false

      add :banned_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :lifted_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :reason, :text, null: true
      add :expires_at, :timestamptz, null: true
      add :lifted_at, :timestamptz, null: true

      timestamps()
    end

    create index(@table, [:community_id, :user_id], prefix: @prefix)

    # A person can have one ban in force per community at a time
    create unique_index(@table, [:community_id, :user_id],
             prefix: @prefix,
             where: "lifted_at IS NULL",
             name: :bans_one_active_index
           )
  end
end
