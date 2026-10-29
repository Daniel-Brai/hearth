defmodule Hearth.Chat.Command.QueueScreening do
  alias Hearth.Chat.Message
  alias Hearth.Communities
  alias Hearth.Media
  alias Hearth.ScreeningPolicy

  # A sound is one of a fixed list of names so there is nothing to screen
  @spec message(Message.t()) :: :ok | {:error, term()}
  def message(%Message{kind: :sound}), do: :ok

  def message(%Message{} = message) do
    ScreeningPolicy.enqueue(:message, message.id, files?(message), fn -> level(message) end)
  end

  # Sent with files, or kept the ones it had
  defp files?(%Message{attachment_ids: [_ | _]}), do: true
  defp files?(%Message{attachment_ids: []}), do: false

  defp files?(%Message{id: id}),
    do: fn -> :message |> Media.list_attachments([id]) |> Map.get(id, []) != [] end

  defp level(%Message{room_id: nil}), do: :none

  defp level(%Message{room_id: room_id}) do
    with {:ok, room} <- Communities.get_room(id: room_id),
         {:ok, community} <- Communities.get_community(id: room.community_id) do
      Communities.moderation_level(community, room)
    else
      _gone -> :none
    end
  end
end
