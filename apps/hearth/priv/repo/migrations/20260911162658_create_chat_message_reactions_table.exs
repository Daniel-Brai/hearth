defmodule Hearth.Repo.Migrations.CreateChatMessageReactionsTable do
  use Ecto.Migration

  @prefix :chat
  @table :message_reactions

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :message_id, references(:messages, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      add :emoji, :string, primary_key: true

      timestamps(updated_at: false)
    end
  end
end
