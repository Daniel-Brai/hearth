defmodule Hearth.Notifications.Worker.ScheduleDigests do
  use Oban.Worker, queue: :digests, max_attempts: 3

  alias Hearth.Accounts
  alias Hearth.Notifications.Worker.SendDigest

  # Catch up emails arrive at 7 in the morning where each person lives
  @hour 7

  # Each email is its own job so one failure retries alone
  @impl Oban.Worker
  def perform(%Oban.Job{scheduled_at: scheduled_at}) do
    # The hour the job was meant for so a late start still finds its people
    at = DateTime.truncate(scheduled_at || DateTime.utc_now(), :second)

    at
    |> Accounts.digest_due_ids(@hour)
    |> Enum.each(&({:ok, _job} = &1 |> SendDigest.job() |> Oban.insert()))

    :ok
  end
end
