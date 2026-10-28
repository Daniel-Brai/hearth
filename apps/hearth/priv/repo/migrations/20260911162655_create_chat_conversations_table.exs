defmodule Hearth.Repo.Migrations.CreateChatConversationsTable do
  use Ecto.Migration

  @prefix :chat

  def change do
    create table(:conversations, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :kind, :string, null: false
      add :name, :string, null: true
      # The two people's ids, sorted and joined so a pair has one direct conversation
      add :direct_key, :string, null: true

      add :created_by_id,
          references(:users, type: :uuid, prefix: :accounts, on_delete: :nilify_all),
          null: true

      timestamps()
    end

    create unique_index(:conversations, :direct_key, prefix: @prefix, where: "kind = 'direct'")

    create table(:conversation_members, prefix: @prefix, primary_key: false) do
      add :conversation_id, references(:conversations, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      # Points at a message and its foreign key is added with the messages table
      add :last_read_message_id, :uuid, null: true
      add :muted, :boolean, null: false, default: false

      timestamps()
    end

    create index(:conversation_members, :user_id, prefix: @prefix)
  end
end
