defmodule Hearth.Instance.Worker.CheckForUpdate do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: :infinity, states: :incomplete]

  alias Hearth.Instance

  @impl Oban.Worker
  def perform(%Oban.Job{}) do
    case Instance.check_for_update() do
      {:ok, _status} -> :ok
      {:error, :disabled} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
