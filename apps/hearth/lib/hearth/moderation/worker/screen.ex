defmodule Hearth.Moderation.Worker.Screen do
  use Oban.Worker, queue: :ai, max_attempts: 10

  alias Hearth.Moderation

  @types %{"post" => :post, "reply" => :reply, "message" => :message}

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"subject_type" => type, "subject_id" => id}}) do
    case @types |> Map.fetch!(type) |> Moderation.screen(id) do
      {:ok, _result} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  # Waiting for a model or provider starts at 15 s then doubles up to an hour
  @impl Oban.Worker
  def backoff(%Oban.Job{attempt: attempt}), do: min(15 * Integer.pow(2, attempt - 1), 3_600)
end
