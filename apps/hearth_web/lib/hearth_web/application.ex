defmodule HearthWeb.Application do
  @moduledoc false

  use Application

  alias Hearth.Roles
  alias HearthWeb.Endpoint
  alias HearthWeb.Guardian.Keys
  alias HearthWeb.PromEx
  alias HearthWeb.RequestLogger

  @impl Application
  def start(_type, _args) do
    Confex.resolve_env!(:hearth_web)

    # A bad signing key stops the boot, not the first sign in
    Keys.load!()
    :ok = RequestLogger.install()
    :ok = OpentelemetryBandit.setup()
    :ok = OpentelemetryPhoenix.setup(adapter: :bandit)

    children = children(Roles.list())

    opts = [strategy: :one_for_one, name: HearthWeb.Supervisor]

    with {:ok, _pid} = result <- Supervisor.start_link(children, opts),
         :ok <- PromEx.seed_event_metrics() do
      result
    end
  end

  @spec children([Roles.role()]) :: [module() | {module(), term()}]
  def children(roles) do
    Roles.children(
      [
        # First so it hears every event the others send while starting
        {PromEx, :all},
        {HearthWeb.Telemetry, :all},
        {{HearthWeb.FloodGuard, clean_period: :timer.minutes(1)}, [:web]},
        {HearthWeb.Presence, [:web]},
        {{Task.Supervisor, name: HearthWeb.OnlineCounts.Tasks}, [:web]},
        {HearthWeb.OnlineCounts, [:web]},
        {Endpoint, [:web]},
        {HearthWeb.MetricsEndpoint, :all},
        {HearthWeb.Broadcaster, :all}
      ],
      roles
    )
  end

  @impl Application
  def config_change(changed, _new, removed) do
    if Roles.enabled?(:web), do: Endpoint.config_change(changed, removed)
    :ok
  end
end
