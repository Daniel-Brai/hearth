defmodule Hearth.Repo.Migrations.CreateMediaMediaTable do
  use Ecto.Migration

  @prefix :media
  @table :media

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true

      add :uploader_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      add :idempotency_key, :string, null: false
      add :name, :string, null: false
      add :purpose, :string, null: false, default: "attachment"
      add :bucket_key, :string, null: false
      add :content_type, :string, null: false
      add :byte_size, :bigint, null: false
      add :sha256, :string, null: false
      add :multipart_upload_id, :text, null: true
      add :width, :integer, null: true
      add :height, :integer, null: true
      add :duration_ms, :integer, null: true
      add :blurhash, :string, null: true
      add :variants, :jsonb, null: false, default: "[]"
      add :status, :string, null: false, default: "uploading"
      add :failure, :text, null: true

      timestamps()
    end

    create unique_index(@table, [:uploader_id, :idempotency_key], prefix: @prefix)
    create index(@table, [:uploader_id, :inserted_at], prefix: @prefix)

    create index(@table, [:inserted_at],
             where: "status = 'uploading'",
             name: :media_uploading_index,
             prefix: @prefix
           )
  end
end
