defmodule HearthWeb.Broadcaster do
  use GenStage

  alias Hearth.PubSub.Websocket
  alias Phoenix.Channel.Server

  @pubsub Application.compile_env!(:hearth_web, [HearthWeb.Endpoint, :pubsub_server])

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenStage.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenStage
  def init(_opts) do
    {:consumer, nil, subscribe_to: [Websocket]}
  end

  @impl GenStage
  def handle_events(events, _from, state) do
    for event <- events, channel <- event.channels do
      Server.broadcast(@pubsub, channel, event.name, event.data)
    end

    {:noreply, [], state}
  end
end
