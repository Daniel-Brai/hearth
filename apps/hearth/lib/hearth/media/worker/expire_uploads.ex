defmodule Hearth.Media.Worker.ExpireUploads do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: 300, states: :incomplete]

  alias Hearth.Media.Asset
  alias Hearth.Media.Command.FailMedia

  @batch 500

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    before = DateTime.add(DateTime.utc_now(), -1, :hour)

    for media <- Asset.unfinished_before(before, @batch) do
      FailMedia.execute(media, "The upload was never finished.")
    end

    :ok
  end
end
