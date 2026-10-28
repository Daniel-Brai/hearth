defmodule Hearth.Repo.Migrations.AddPreviewHiddenToChatMessages do
  use Ecto.Migration

  @prefix :chat
  @table :messages

  # The author or a moderator took the link preview off
  def change do
    alter table(@table, prefix: @prefix) do
      add :preview_hidden_at, :timestamptz, null: true
    end
  end
end
