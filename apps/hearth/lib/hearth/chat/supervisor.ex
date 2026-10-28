defmodule Hearth.Chat.Supervisor do
  use Supervisor

  alias Hearth.Chat.ReadMarkers

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(_opts) do
    Supervisor.init([ReadMarkers], strategy: :one_for_one)
  end
end
