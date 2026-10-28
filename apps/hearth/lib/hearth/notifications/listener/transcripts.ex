defmodule Hearth.Notifications.Listener.Transcripts do
  use GenServer

  alias Hearth.Notifications.Worker.TellTranscript
  alias Hearth.Transcripts
  alias Hearth.Transcripts.TranscriptReady

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Transcripts.subscribe_to_pubsub()

    {:ok, nil}
  end

  # Only a session held for an event has people waiting to read it
  @impl GenServer
  def handle_info(%TranscriptReady{event_id: event_id} = ready, state) when is_binary(event_id) do
    {:ok, _job} =
      %{event_id: event_id, session_id: ready.session_id}
      |> TellTranscript.new()
      |> Oban.insert()

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
