defmodule Hearth.Repo.Migrations.CreateChatPollVotesTable do
  use Hearth.Repo.Migration

  @prefix :chat
  @table :poll_votes

  # A new table is empty, so its references and indexes lock nothing anyone is reading
  # excellent_migrations:safety-assured-for-this-file column_reference_added index_not_concurrently

  # One row per option a person picked, so a poll that takes several answers has several rows
  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :option_id, references(:poll_options, type: :uuid, on_delete: :delete_all),
        primary_key: true

      add :user_id, references(:users, type: :uuid, prefix: :accounts, on_delete: :delete_all),
        primary_key: true

      add :poll_id, references(:polls, type: :uuid, on_delete: :delete_all), null: false

      timestamps(updated_at: false)
    end

    create index(@table, [:poll_id, :user_id], prefix: @prefix)
  end
end
