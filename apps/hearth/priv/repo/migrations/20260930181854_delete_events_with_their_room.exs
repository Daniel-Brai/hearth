defmodule Hearth.Repo.Migrations.DeleteEventsWithTheirRoom do
  use Ecto.Migration

  # An event held in a room can't be left without one so deleting a room
  # deletes its events, as it does its messages
  def change do
    alter table(:events, prefix: :events) do
      modify :room_id,
             references(:rooms, type: :uuid, prefix: :communities, on_delete: :delete_all),
             from: references(:rooms, type: :uuid, prefix: :communities, on_delete: :nilify_all)
    end
  end
end
