defmodule Hearth.Notifications.Worker.TellLive do
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [period: 3_600, keys: [:session_id]]

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.Notifications
  alias Hearth.Notifications.Notices

  @batch 500

  # A job so a large community is still told if the node restarts
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"room_id" => room_id, "host_id" => host_id} = args}) do
    with {:ok, room} <- Communities.get_room(id: room_id),
         {:ok, community} <- Communities.get_community(id: room.community_id),
         {:ok, host} <- Accounts.get_user(id: host_id) do
      notice =
        Notices.live_started(%{
          actor: host,
          community: community,
          room: room,
          session_id: args["session_id"],
          topic: args["topic"]
        })

      community.id
      |> IAM.member_roles()
      |> Map.keys()
      |> List.delete(host.id)
      |> Enum.chunk_every(@batch)
      |> Enum.each(fn ids ->
        ids
        |> Accounts.list_users()
        |> Enum.filter(&Communities.room_visible?(&1, room))
        |> Enum.each(&Notifications.send(&1, notice))
      end)
    end

    :ok
  end
end
