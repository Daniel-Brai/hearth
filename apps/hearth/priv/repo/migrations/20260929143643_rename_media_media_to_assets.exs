defmodule Hearth.Repo.Migrations.RenameMediaMediaToAssets do
  use Ecto.Migration

  # Ecto names constraints after the table so they move with it
  # or a repeated idempotency key would raise instead of a changeset error
  @renames [
    {"INDEX", "media_pkey", "assets_pkey"},
    {"INDEX", "media_uploader_id_idempotency_key_index",
     "assets_uploader_id_idempotency_key_index"},
    {"INDEX", "media_uploader_id_inserted_at_index", "assets_uploader_id_inserted_at_index"},
    {"INDEX", "media_uploading_index", "assets_uploading_index"}
  ]

  def up do
    rename table(:media, prefix: :media), to: table(:assets, prefix: :media)

    execute "ALTER TABLE media.assets RENAME CONSTRAINT media_uploader_id_fkey TO assets_uploader_id_fkey"

    for {kind, from, to} <- @renames, do: execute("ALTER #{kind} media.#{from} RENAME TO #{to}")
  end

  def down do
    for {kind, from, to} <- @renames, do: execute("ALTER #{kind} media.#{to} RENAME TO #{from}")

    execute "ALTER TABLE media.assets RENAME CONSTRAINT assets_uploader_id_fkey TO media_uploader_id_fkey"

    rename table(:assets, prefix: :media), to: table(:media, prefix: :media)
  end
end
