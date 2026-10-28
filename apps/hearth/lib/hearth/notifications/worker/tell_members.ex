defmodule Hearth.Notifications.Worker.TellMembers do
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [period: 3_600, keys: [:event_id]]

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.IAM
  alias Hearth.Notifications
  alias Hearth.Notifications.Notices

  @batch 500

  # A job so a large community is still told if the node restarts
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_id" => event_id}}) do
    with {:ok, event} <- Events.get_event(id: event_id),
         {:ok, community} <- Communities.get_community(id: event.community_id),
         {:ok, host} <- Accounts.get_user(id: event.host_id) do
      notice = Notices.event_scheduled(%{actor: host, community: community, event: event})

      community.id
      |> IAM.member_roles()
      |> Map.keys()
      |> List.delete(host.id)
      |> Enum.chunk_every(@batch)
      |> Enum.each(fn ids ->
        ids |> Accounts.list_users() |> Enum.each(&Notifications.send(&1, notice))
      end)
    end

    :ok
  end
end
