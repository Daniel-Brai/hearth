defmodule Hearth.Notifications.Worker.PruneRead do
  use Oban.Worker, queue: :default, max_attempts: 3

  alias Hearth.Notifications

  # Long enough to look back over a season, short enough that the table
  # stays about the size of what people still read
  @keep_days 90

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    _count = DateTime.utc_now() |> DateTime.add(-@keep_days, :day) |> Notifications.prune_read()

    :ok
  end
end
