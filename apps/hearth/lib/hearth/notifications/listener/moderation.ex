defmodule Hearth.Notifications.Listener.Moderation do
  use GenServer

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.Moderation
  alias Hearth.Moderation.ItemQueued
  alias Hearth.Notifications
  alias Hearth.Notifications.Notices

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Moderation.subscribe_to_pubsub()

    {:ok, nil}
  end

  @impl GenServer
  def handle_info(%ItemQueued{community_id: nil} = event, state) do
    with {:ok, item} <- Moderation.get_item(event.item_id) do
      notice =
        case item.held do
          true -> Notices.held_for_instance(%{item: item})
          false -> Notices.direct_message_reported(%{item: item})
        end

      Accounts.list_instance_admins()
      |> Enum.reject(&(&1.id in [event.reporter_id, event.author_id]))
      |> Enum.each(&Notifications.send(&1, notice))
    end

    {:noreply, state}
  end

  def handle_info(%ItemQueued{} = event, state) do
    with {:ok, item} <- Moderation.get_item(event.item_id),
         {:ok, community} <- Communities.get_community(id: event.community_id) do
      notice = Notices.queued(%{community: community, item: item})

      community.id
      |> IAM.holders("content.remove")
      |> Enum.reject(&(&1 in [event.reporter_id, event.author_id]))
      |> Accounts.list_users()
      |> Enum.each(&Notifications.send(&1, notice))
    end

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
