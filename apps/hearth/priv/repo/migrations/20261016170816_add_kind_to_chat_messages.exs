defmodule Hearth.Repo.Migrations.AddKindToChatMessages do
  use Ecto.Migration

  @prefix :chat
  @table :messages

  # A promoted message is the room's note pointing at the post its messages became
  def change do
    alter table(@table, prefix: @prefix) do
      add :kind, :string, null: false, default: "text"

      add :post_id, references(:posts, type: :uuid, prefix: :forum, on_delete: :delete_all),
        null: true
    end
  end
end
