defmodule Hearth.PubSub.Websocket do
  use GenStage

  alias GenStage.BroadcastDispatcher
  alias Hearth.PubSub.WebsocketEvent

  @spec broadcast(WebsocketEvent.t()) :: :ok
  def broadcast(%WebsocketEvent{} = event) do
    GenStage.call(__MODULE__, event)
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenStage
  def init(_opts) do
    {:producer, nil, dispatcher: BroadcastDispatcher}
  end

  @impl GenStage
  def handle_call(%WebsocketEvent{} = event, _from, state) do
    {:reply, :ok, [event], state}
  end

  @impl GenStage
  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end
end
