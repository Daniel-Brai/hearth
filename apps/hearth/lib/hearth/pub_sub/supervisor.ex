defmodule Hearth.PubSub.Supervisor do
  use Supervisor

  alias Hearth.PubSub.Websocket

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(_opts) do
    children = [
      {Phoenix.PubSub, name: Hearth.PubSub},
      Websocket
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
