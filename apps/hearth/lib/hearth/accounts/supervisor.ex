defmodule Hearth.Accounts.Supervisor do
  use Supervisor

  alias Hearth.Accounts.LastSeen
  alias Hearth.Accounts.Taken

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  def init(_opts) do
    Supervisor.init([Taken, LastSeen], strategy: :one_for_one)
  end
end
