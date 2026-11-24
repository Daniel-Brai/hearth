defmodule Hearth.Notifications.Worker.ScheduleDigests do
  use Oban.Worker, queue: :digests, max_attempts: 3

  alias Hearth.Accounts
  alias Hearth.Notifications.Worker.SendDigest

  # Catch up emails arrive at 7 in the morning where each person lives
  @hour 7

  @impl Oban.Worker
  def perform(%Oban.Job{scheduled_at: scheduled_at}) do
    # A late start still finds the people for the hour it was meant for
    at = DateTime.truncate(scheduled_at || DateTime.utc_now(), :second)

    at
    |> Accounts.list_digest_readers(@hour)
    |> Enum.each(&({:ok, _job} = &1 |> SendDigest.job() |> Oban.insert()))

    :ok
  end
end
