defmodule Hearth.Repo.Migrations.CreateVoiceRecordings do
  use Ecto.Migration

  @prefix :voice

  @actions_before ~w[removed restored kept banned unbanned server_muted server_mute_lifted
                     disconnected moved_to_listeners pinned locked changed]
  @actions_after @actions_before ++ ~w[recording_started recording_stopped]

  def up do
    create table(:recordings, prefix: @prefix) do
      add :session_id,
          references(:sessions, type: :uuid, prefix: @prefix, on_delete: :delete_all),
          null: false

      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: false

      add :room_id, references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
        null: false

      add :started_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :status, :text, null: false
      add :failure, :text, null: true
      add :started_at, :timestamptz, null: false
      add :ended_at, :timestamptz, null: true
      add :tracks, :jsonb, null: false, default: "[]"
      add :speakers, :jsonb, null: false, default: "[]"
      add :has_screen, :boolean, null: false, default: false
      add :duration_ms, :integer, null: true
      add :byte_size, :bigint, null: true
      add :width, :integer, null: true
      add :height, :integer, null: true
      add :video_key, :text, null: true
      add :poster_key, :text, null: true
      add :processing_ms, :integer, null: true

      timestamps()
    end

    create constraint(:recordings, :status,
             check: "status IN ('recording', 'processing', 'ready', 'failed')",
             prefix: @prefix
           )

    create unique_index(:recordings, [:session_id],
             prefix: @prefix,
             where: "status = 'recording'",
             name: :recordings_one_running_per_session
           )

    create index(:recordings, [:room_id], prefix: @prefix)

    replace_actions(@actions_after)
  end

  def down do
    replace_actions(@actions_before)

    drop table(:recordings, prefix: @prefix)
  end

  defp replace_actions(actions) do
    drop constraint(:actions, :action, prefix: :moderation)

    create constraint(:actions, :action,
             check: "action IN (#{Enum.map_join(actions, ", ", &"'#{&1}'")})",
             prefix: :moderation
           )
  end
end
