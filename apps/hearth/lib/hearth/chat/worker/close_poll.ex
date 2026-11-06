defmodule Hearth.Chat.Worker.ClosePoll do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: :infinity, keys: [:poll_id], states: :incomplete]

  alias Hearth.Chat
  alias Hearth.Chat.Poll

  @spec enqueue(Poll.t()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(%Poll{closes_at: %DateTime{} = closes_at} = poll) do
    %{poll_id: poll.id}
    |> new(scheduled_at: closes_at)
    |> Oban.insert()
  end

  # A poll its starter already closed, or one deleted with its message, leaves nothing to do
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"poll_id" => id}}) do
    case Poll.get(id: id, closed_at: nil, preload: :options) do
      nil -> :ok
      %Poll{} = poll -> with {:ok, _poll} <- Chat.expire_poll(poll), do: :ok
    end
  end
end
