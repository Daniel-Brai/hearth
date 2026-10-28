defmodule Hearth.PubSub do
  use Boundary, deps: [Hearth.Common], exports: [WebsocketEvent]

  alias Hearth.Common
  alias Hearth.PubSub.Websocket
  alias Hearth.PubSub.WebsocketEvent
  alias Phoenix.PubSub

  @spec subscribe(String.t(), keyword()) :: :ok | {:error, term()}
  def subscribe(topic, opts \\ []) do
    PubSub.subscribe(__MODULE__, topic, opts)
  end

  @spec broadcast(String.t(), term()) :: :ok | {:error, term()}
  def broadcast(topic, message) do
    with :ok <- PubSub.broadcast(__MODULE__, topic, message),
         true <- Common.implements?(message, WebsocketEvent) do
      send_to_websocket(message)
    else
      false -> :ok
      error -> error
    end
  end

  defp send_to_websocket(%module{} = message) do
    channels =
      message
      |> module.broadcast_on()
      |> List.wrap()

    event = %WebsocketEvent{
      name: module.broadcast_as(message),
      data: module.broadcast_with(message),
      channels: channels
    }

    Websocket.broadcast(event)
  end
end
