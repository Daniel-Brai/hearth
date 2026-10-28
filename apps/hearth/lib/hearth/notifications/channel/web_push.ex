defmodule Hearth.Notifications.Channel.WebPush do
  @behaviour Hearth.Notifications.Channel

  alias Hearth.Notifications.Notifiable
  alias Hearth.Notifications.WebPush
  alias Hearth.Notifications.Worker.DeliverWebPush

  @impl Hearth.Notifications.Channel
  def name, do: :web_push

  @impl Hearth.Notifications.Channel
  def send(%module{} = message, %_{} = notifiable) do
    case WebPush.enabled?() do
      true -> queue(module.to_web_push(message, notifiable), notifiable)
      false -> :ok
    end
  end

  defp queue(push, notifiable) do
    payload =
      push
      |> Map.drop([:__struct__, :options])
      |> Jason.encode!()

    options = Map.new(push.options)

    notifiable
    |> Notifiable.recipients(name())
    |> Enum.each(&DeliverWebPush.enqueue(&1.id, payload, options))
  end
end
