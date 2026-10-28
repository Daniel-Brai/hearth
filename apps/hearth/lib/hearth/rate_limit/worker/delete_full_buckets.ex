defmodule Hearth.RateLimit.Worker.DeleteFullBuckets do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 300, states: :incomplete]

  alias Hearth.RateLimit.Bucket

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    _deleted = Bucket.delete_full()

    :ok
  end
end
