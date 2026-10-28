defmodule Hearth.Repo.Migrations.CreateVoiceTables do
  # At most one live session per room

  use Ecto.Migration

  @prefix :voice

  @actions_before ~w[removed restored kept banned unbanned server_muted pinned locked changed]
  @actions_after @actions_before ++ ~w[server_mute_lifted disconnected moved_to_listeners]

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS voice"

    create table(:sessions, prefix: @prefix) do
      add :room_id, references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
        null: false

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :host_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
        null: true

      add :event_id, references(:events, type: :uuid, prefix: :events, on_delete: :nilify_all),
        null: true

      add :post_id, references(:posts, type: :uuid, prefix: :forum, on_delete: :nilify_all),
        null: true

      add :mode, :text, null: false
      add :topic, :text, null: true
      add :node, :text, null: true
      add :started_at, :timestamptz, null: false
      add :ended_at, :timestamptz, null: true
      add :peak_participants, :integer, null: false, default: 0
      add :restarts, :integer, null: false, default: 0

      timestamps()
    end

    create constraint(:sessions, :mode, check: "mode IN ('stage', 'open')", prefix: @prefix)

    create unique_index(:sessions, [:room_id],
             prefix: @prefix,
             where: "ended_at IS NULL",
             name: :sessions_one_live_per_room
           )

    create index(:sessions, [:community_id], prefix: @prefix)

    create table(:participants, prefix: @prefix) do
      add :session_id,
          references(:sessions, type: :uuid, prefix: @prefix, on_delete: :delete_all),
          null: false

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: false

      add :role, :text, null: false
      add :joined_at, :timestamptz, null: false
      add :left_at, :timestamptz, null: true
      add :hand_raised_at, :timestamptz, null: true
      add :self_muted, :boolean, null: false, default: true
      add :server_muted_at, :timestamptz, null: true

      add :server_muted_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      timestamps()
    end

    create constraint(:participants, :role,
             check: "role IN ('host', 'speaker', 'listener')",
             prefix: @prefix
           )

    create unique_index(:participants, [:session_id, :user_id], prefix: @prefix)

    replace_actions(@actions_after)
  end

  def down do
    replace_actions(@actions_before)

    drop table(:participants, prefix: @prefix)
    drop table(:sessions, prefix: @prefix)

    execute "DROP SCHEMA IF EXISTS voice"
  end

  defp replace_actions(actions) do
    drop constraint(:actions, :action, prefix: :moderation)

    create constraint(:actions, :action,
             check: "action IN (#{Enum.map_join(actions, ", ", &"'#{&1}'")})",
             prefix: :moderation
           )
  end
end
