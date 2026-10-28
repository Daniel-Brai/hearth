defmodule Hearth.Repo.Migrations.CreateModerationTables do
  # Items and the log name their subject without a foreign key so history survives the content being deleted

  use Ecto.Migration

  @prefix :moderation

  def up do
    execute "CREATE SCHEMA IF NOT EXISTS moderation"

    create table(:items, prefix: @prefix) do
      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: true

      add :room_id, references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
        null: true

      add :source, :text, null: false
      add :subject_type, :text, null: false
      add :subject_id, :uuid, null: false
      add :author_id, :uuid, null: false
      add :reason, :text, null: true
      add :note, :text, null: true
      add :score, :float, null: true
      add :status, :text, null: false, default: "pending"
      add :report_count, :integer, null: false, default: 0

      add :reviewed_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :reviewed_at, :timestamptz, null: true

      timestamps()
    end

    create constraint(:items, :source,
             check: "source IN ('automatic', 'report', 'instance')",
             prefix: @prefix
           )

    create constraint(:items, :subject_type,
             check: "subject_type IN ('post', 'reply', 'message')",
             prefix: @prefix
           )

    create constraint(:items, :status,
             check: "status IN ('pending', 'kept', 'removed', 'dismissed')",
             prefix: @prefix
           )

    # Direct messages belong to no community and go to the instance admins
    create constraint(:items, :community_or_instance,
             check: "community_id IS NOT NULL OR source = 'instance'",
             prefix: @prefix
           )

    # One open item per piece of content and more reports join it
    create unique_index(:items, [:subject_type, :subject_id],
             prefix: @prefix,
             where: "status = 'pending'",
             name: :items_one_pending_index
           )

    create index(:items, ~w[community_id status inserted_at]a, prefix: @prefix)
    create index(:items, ~w[source status inserted_at]a, prefix: @prefix)

    create table(:reports, prefix: @prefix) do
      add :item_id, references(:items, type: :uuid, on_delete: :delete_all), null: false

      add :reporter_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
          null: false

      add :reason, :text, null: false
      add :note, :text, null: true

      timestamps(updated_at: false)
    end

    create constraint(:reports, :reason,
             check:
               "reason IN ('spam', 'harassment', 'hate', 'sexual', 'violence', 'off_topic', 'other')",
             prefix: @prefix
           )

    create unique_index(:reports, [:item_id, :reporter_id], prefix: @prefix)

    create table(:actions, prefix: @prefix) do
      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :delete_all),
          null: true

      add :actor_id, :uuid, null: false
      add :target_id, :uuid, null: true
      add :action, :text, null: false
      add :subject_type, :text, null: false
      add :subject_id, :uuid, null: false
      add :reason, :text, null: true
      add :metadata, :map, null: false, default: %{}

      timestamps(updated_at: false)
    end

    create constraint(:actions, :action,
             check:
               "action IN ('removed', 'restored', 'kept', 'banned', 'unbanned', 'server_muted', 'pinned', 'locked', 'changed')",
             prefix: @prefix
           )

    create index(:actions, [:community_id, :inserted_at], prefix: @prefix)
  end

  def down do
    drop table(:actions, prefix: @prefix)
    drop table(:reports, prefix: @prefix)
    drop table(:items, prefix: @prefix)

    execute "DROP SCHEMA IF EXISTS moderation"
  end
end
