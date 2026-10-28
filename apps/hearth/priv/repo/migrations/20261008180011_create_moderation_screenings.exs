defmodule Hearth.Repo.Migrations.CreateModerationScreenings do
  use Ecto.Migration

  @prefix :moderation

  def up do
    alter table(:items, prefix: @prefix) do
      add :held, :boolean, null: false, default: false
    end

    execute "UPDATE moderation.items SET held = true WHERE source = 'automatic'"

    create table(:screenings, prefix: @prefix) do
      add :community_id,
          references(:communities, type: :uuid, prefix: :communities, on_delete: :nilify_all),
          null: true

      add :subject_type, :text, null: false
      add :subject_id, :uuid, null: false
      add :screener, :text, null: false
      add :verdict, :text, null: false
      add :score, :float, null: false
      add :categories, {:array, :text}, null: false, default: []
      add :held, :boolean, null: false, default: false
      add :outcome, :text, null: true
      add :duration_ms, :integer, null: false

      timestamps()
    end

    create constraint(:screenings, :subject_type,
             check: "subject_type IN ('post', 'reply', 'message')",
             prefix: @prefix
           )

    create constraint(:screenings, :verdict,
             check: "verdict IN ('safe', 'controversial', 'unsafe')",
             prefix: @prefix
           )

    create constraint(:screenings, :outcome,
             check: "outcome IN ('kept', 'removed')",
             prefix: @prefix
           )

    create index(:screenings, [:subject_type, :subject_id], prefix: @prefix)
    create index(:screenings, [:inserted_at], prefix: @prefix)
  end

  def down do
    drop table(:screenings, prefix: @prefix)

    alter table(:items, prefix: @prefix) do
      remove :held
    end
  end
end
