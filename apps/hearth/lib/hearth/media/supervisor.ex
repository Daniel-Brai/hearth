defmodule Hearth.Media.Supervisor do
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  if Mix.env() == :test do
    def init(_opts), do: :ignore
  else
    def init(_opts) do
      Supervisor.init([Hearth.Media.Listener.Accounts], strategy: :one_for_one)
    end
  end
end
