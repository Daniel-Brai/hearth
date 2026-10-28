defmodule Hearth.RTC.Supervisor do
  # Peers are temporary since a dead connection is rebuilt by the browser rejoining

  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl Supervisor
  def init(_opts) do
    children = [
      {Registry, keys: :duplicate, name: Hearth.RTC.Tracks},
      {PartitionSupervisor, child_spec: DynamicSupervisor, name: Hearth.RTC.PeerSupervisor}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
