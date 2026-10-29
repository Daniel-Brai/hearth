defmodule Hearth.Notifications.Listener.Chat do
  use GenServer

  alias Hearth.Accounts
  alias Hearth.Chat
  alias Hearth.Chat.MessageCreated
  alias Hearth.Communities
  alias Hearth.Notifications
  alias Hearth.Notifications.Mentions
  alias Hearth.Notifications.Notices

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Chat.subscribe_to_pubsub()

    {:ok, nil}
  end

  # A direct message tells the others and a room message tells who it mentions
  @impl GenServer
  def handle_info(%MessageCreated{conversation_id: id} = event, state) when is_binary(id) do
    with {:ok, actor} <- Accounts.get_user(id: event.author_id),
         {:ok, message} <- Chat.get_message(event.message_id),
         {:ok, conversation} <- Chat.get_conversation(actor, id) do
      notice = Notices.direct_message(%{actor: actor, message: message})

      conversation.members
      |> Enum.map(& &1.user_id)
      |> Enum.reject(&(&1 == actor.id))
      |> Accounts.list_users()
      |> Enum.each(&Notifications.send(&1, notice))
    end

    {:noreply, state}
  end

  def handle_info(%MessageCreated{room_id: room_id} = event, state) when is_binary(room_id) do
    with {:ok, actor} <- Accounts.get_user(id: event.author_id),
         {:ok, %{kind: :text} = message} <- Chat.get_message(event.message_id),
         {:ok, room} <- Communities.get_room(id: room_id),
         {:ok, community} <- Communities.get_community(id: room.community_id) do
      Mentions.notify(%{
        actor: actor,
        community: community,
        room: room,
        body: message.body,
        subject: {"message", message.id},
        data: %{message_id: message.id, room_slug: room.slug},
        url: "/c/#{community.slug}/#{place(room)}/#{room.slug}"
      })
    end

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}

  # A voice room keeps its chat beside the call, so a mention there opens the room
  defp place(%{type: :voice}), do: "voice"
  defp place(_room), do: "chat"
end
