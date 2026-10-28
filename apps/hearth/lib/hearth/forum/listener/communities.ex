defmodule Hearth.Forum.Listener.Communities do
  use GenServer

  alias Hearth.Communities
  alias Hearth.Communities.CommunityCreated
  alias Hearth.Forum

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
  def handle_info(%CommunityCreated{} = event, state) do
    {:ok, _kinds} = Forum.create_default_kinds(event.community_id, event.template)

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
