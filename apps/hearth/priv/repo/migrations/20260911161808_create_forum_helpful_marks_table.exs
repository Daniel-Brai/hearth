defmodule Hearth.Repo.Migrations.CreateForumHelpfulMarksTable do
  use Ecto.Migration

  @prefix :forum
  @table :helpful_marks

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        null: false

      add :post_id, references(:posts, type: :uuid, on_delete: :delete_all), null: true
      add :reply_id, references(:replies, type: :uuid, on_delete: :delete_all), null: true

      timestamps(updated_at: false)
    end

    create constraint(@table, :one_subject,
             check: "num_nonnulls(post_id, reply_id) = 1",
             prefix: @prefix
           )

    create unique_index(@table, [:user_id, :post_id],
             prefix: @prefix,
             where: "post_id IS NOT NULL"
           )

    create unique_index(@table, [:user_id, :reply_id],
             prefix: @prefix,
             where: "reply_id IS NOT NULL"
           )
  end
end
