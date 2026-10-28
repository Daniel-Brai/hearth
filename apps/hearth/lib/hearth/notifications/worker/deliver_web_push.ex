defmodule Hearth.Notifications.Worker.DeliverWebPush do
  use Oban.Worker, queue: :push, max_attempts: 5

  alias Hearth.Notifications.PushSubscription
  alias Hearth.Notifications.SealedArgs
  alias Hearth.Notifications.WebPush

  # The payload is sealed since it can quote a direct message
  @spec enqueue(String.t(), String.t(), map()) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(subscription_id, payload, %{} = options \\ %{}) do
    %{subscription_id: subscription_id, sealed: SealedArgs.seal(payload), options: options}
    |> new()
    |> Oban.insert()
  end

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"subscription_id" => id, "sealed" => sealed} = args}) do
    payload = SealedArgs.open!(sealed)

    case PushSubscription.get(id: id) do
      nil -> :ok
      %PushSubscription{} = subscription -> deliver(subscription, payload, args["options"] || %{})
    end
  end

  defp deliver(subscription, payload, options) do
    opts =
      [ttl: options["ttl"], urgency: options["urgency"], topic: options["topic"]]
      |> Enum.reject(&match?({_key, nil}, &1))
      |> Keyword.put(:vapid_keys, WebPush.vapid_keys())

    case WebPush.send(subscription, payload, opts) do
      :ok ->
        PushSubscription.update(subscription, %{last_used_at: DateTime.utc_now()})
        :ok

      # The browser dropped the subscription so it can never be used again
      {:error, :expired} ->
        PushSubscription.delete(subscription)
        :ok

      {:error, :payload_too_large} ->
        {:cancel, :payload_too_large}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
