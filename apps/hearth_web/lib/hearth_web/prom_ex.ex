defmodule HearthWeb.PromEx do
  use PromEx, otp_app: :hearth_web

  alias PromEx.Plugins.Application
  alias PromEx.Plugins.Beam
  alias PromEx.Plugins.Ecto
  alias PromEx.Plugins.Phoenix

  @impl PromEx
  def plugins do
    [
      Beam,
      {PromEx.Plugins.PromEx, otp_app: :hearth},
      {Application, otp_app: :hearth},
      {Ecto, otp_app: :hearth},
      {PromEx.Plugins.Oban, otp_app: :hearth, oban_supervisors: [Oban]},
      Application,
      {Phoenix, endpoint: HearthWeb.Endpoint, router: HearthWeb.Router}
    ]
  end

  @impl PromEx
  def dashboards do
    [
      {:prom_ex, "beam.json"},
      {:prom_ex, "application.json", assigns(:hearth, :application)},
      {:prom_ex, "ecto.json", assigns(:hearth, :ecto)},
      {:prom_ex, "oban.json", assigns(:hearth, :oban)},
      {:prom_ex, "application.json"},
      {:prom_ex, "phoenix.json"}
    ]
  end

  @impl PromEx
  def dashboard_assigns do
    [
      datasource_id: "prometheus",
      default_selected_interval: "30s"
    ]
  end

  @doc "Both start events fire before PromEx is listening and the Ecto and Oban dashboards need what they carry"
  @spec seed_event_metrics() :: :ok
  def seed_event_metrics do
    for repo <- Elixir.Application.fetch_env!(:hearth, :ecto_repos) do
      :telemetry.execute(
        ~w[ecto repo init]a,
        %{system_time: System.system_time()},
        %{repo: repo, opts: Elixir.Application.get_env(:hearth, repo, [])}
      )
    end

    case Oban.whereis(Oban) do
      nil ->
        :ok

      pid ->
        :telemetry.execute(
          ~w[oban supervisor init]a,
          %{system_time: System.system_time()},
          %{pid: pid, conf: Oban.config(Oban)}
        )
    end

    :ok
  end

  defp assigns(otp_app, plugin) do
    [
      title:
        "#{Macro.camelize(Atom.to_string(otp_app))} - PromEx #{Macro.camelize(Atom.to_string(plugin))} Dashboard",
      metric_prefix: [otp_app, :prom_ex, plugin],
      application_metric_prefix: "#{otp_app}_prom_ex_application",
      beam_metric_prefix: "#{otp_app}_prom_ex_beam",
      ecto_metric_prefix: "#{otp_app}_prom_ex_ecto",
      oban_metric_prefix: "#{otp_app}_prom_ex_oban",
      phoenix_metric_prefix: "#{otp_app}_prom_ex_phoenix",
      prom_ex_metric_prefix: "#{otp_app}_prom_ex_prom_ex"
    ]
  end
end
