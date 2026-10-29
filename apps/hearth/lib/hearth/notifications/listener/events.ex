defmodule Hearth.Notifications.Listener.Events do
  use GenServer

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.Events.EventReminder
  alias Hearth.Events.EventScheduled
  alias Hearth.Notifications
  alias Hearth.Notifications.Notices
  alias Hearth.Notifications.Worker.TellMembers

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Events.subscribe_to_pubsub()

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(%EventReminder{} = event, state) do
    with {:ok, scheduled} <- Events.get_event(id: event.event_id),
         {:ok, community} <- Communities.get_community(id: event.community_id) do
      notice =
        Notices.event_reminder(%{community: community, event: scheduled, minutes: event.minutes})

      event.user_ids
      |> Accounts.list_users()
      |> Enum.filter(&Events.visible?(&1, scheduled))
      |> Enum.each(&Notifications.send(&1, notice))
    end

    {:noreply, state}
  end

  def handle_info(%EventScheduled{notify: true, event_id: id}, state) do
    {:ok, _job} = %{event_id: id} |> TellMembers.new() |> Oban.insert()

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
