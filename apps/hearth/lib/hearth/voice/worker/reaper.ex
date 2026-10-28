defmodule Hearth.Voice.Worker.Reaper do
  use Oban.Worker, queue: :default, max_attempts: 1

  alias Hearth.Voice

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    _ended = Voice.end_orphans()
    :ok
  end
end
