defmodule Hearth.Notifications.Worker.TellTranscript do
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [period: :infinity, keys: [:session_id]]

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.Notifications
  alias Hearth.Notifications.Notices

  # A job so people are still told if the node restarts
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"event_id" => event_id, "session_id" => session_id}}) do
    with {:ok, event} <- Events.get_event(id: event_id),
         {:ok, community} <- Communities.get_community(id: event.community_id) do
      notice =
        Notices.transcript_ready(%{community: community, event: event, session_id: session_id})

      [event]
      |> Events.interested_ids()
      |> Map.get(event.id, [])
      |> Accounts.list_users()
      |> Enum.filter(&Events.visible?(&1, event))
      |> Enum.each(&Notifications.send(&1, notice))
    end

    :ok
  end
end
