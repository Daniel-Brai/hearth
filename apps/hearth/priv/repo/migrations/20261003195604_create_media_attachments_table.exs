defmodule Hearth.Repo.Migrations.CreateMediaAttachmentsTable do
  use Ecto.Migration

  @prefix :media
  @table :attachments

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :media_id, references(:assets, type: :uuid, on_delete: :delete_all), null: false
      add :position, :integer, null: false

      add :post_id, references(:posts, type: :uuid, prefix: :forum, on_delete: :delete_all),
        null: true

      add :reply_id, references(:replies, type: :uuid, prefix: :forum, on_delete: :delete_all),
        null: true

      add :message_id, references(:messages, type: :uuid, prefix: :chat, on_delete: :delete_all),
        null: true

      timestamps(updated_at: false)
    end

    create constraint(@table, :one_owner,
             check: "num_nonnulls(post_id, reply_id, message_id) = 1",
             prefix: @prefix
           )

    create index(@table, [:post_id, :position], prefix: @prefix, where: "post_id IS NOT NULL")
    create index(@table, [:reply_id, :position], prefix: @prefix, where: "reply_id IS NOT NULL")

    create index(@table, [:message_id, :position],
             prefix: @prefix,
             where: "message_id IS NOT NULL"
           )

    create index(@table, [:media_id], prefix: @prefix)
  end
end
