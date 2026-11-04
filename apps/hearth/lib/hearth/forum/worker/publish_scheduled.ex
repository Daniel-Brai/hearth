defmodule Hearth.Forum.Worker.PublishScheduled do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:scheduled_id, :send_at], states: :incomplete]

  alias Hearth.Forum
  alias Hearth.Forum.ScheduledPost

  @spec enqueue(ScheduledPost.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(%ScheduledPost{} = scheduled) do
    %{scheduled_id: scheduled.id, send_at: DateTime.to_iso8601(scheduled.send_at)}
    |> new(scheduled_at: scheduled.send_at)
    |> Oban.insert()
  end

  # A post moved to another time or already failed leaves this job with nothing to do
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"scheduled_id" => id, "send_at" => send_at}}) do
    {:ok, at, 0} = DateTime.from_iso8601(send_at)

    with %ScheduledPost{failure: nil} = scheduled <- ScheduledPost.get(id: id),
         :eq <- DateTime.compare(scheduled.send_at, at) do
      _published = Forum.publish_scheduled(scheduled)
      :ok
    else
      _skipped -> :ok
    end
  end
end
