defmodule Hearth.Voice.Listener.Communities do
  use GenServer

  alias Hearth.Communities
  alias Hearth.Communities.RoomAccessChanged
  alias Hearth.Voice

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Communities.subscribe_to_pubsub()

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(%RoomAccessChanged{} = event, state) do
    :ok = Voice.remove_hidden(event.community_id, event.room_id, event.user_id)

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
