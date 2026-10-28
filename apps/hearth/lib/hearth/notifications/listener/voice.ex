defmodule Hearth.Notifications.Listener.Voice do
  use GenServer

  alias Hearth.Notifications.Worker.TellLive
  alias Hearth.Voice
  alias Hearth.Voice.VoiceSessionStarted

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Voice.subscribe_to_pubsub()

    {:ok, nil}
  end

  # A live discussion of a post asks only the people reading it, on the post
  @impl GenServer
  def handle_info(%VoiceSessionStarted{post_id: nil} = event, state) do
    {:ok, _job} =
      %{
        session_id: event.session_id,
        community_id: event.community_id,
        room_id: event.room_id,
        host_id: event.host_id,
        topic: event.topic
      }
      |> TellLive.new()
      |> Oban.insert()

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
