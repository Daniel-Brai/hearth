defmodule Hearth.Repo.Migrations.CreateChatPollOptionsTable do
  use Hearth.Repo.Migration

  @prefix :chat
  @table :poll_options

  def change do
    create table(@table, prefix: @prefix, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :poll_id, references(:polls, type: :uuid, on_delete: :delete_all), null: false
      add :label, :binary, null: false
      add :position, :integer, null: false

      timestamps()
    end

    create unique_index(@table, [:poll_id, :position], prefix: @prefix)
  end
end
