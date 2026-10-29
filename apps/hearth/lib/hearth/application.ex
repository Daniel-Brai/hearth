defmodule Hearth.Application do
  @moduledoc false

  use Application

  alias Hearth.AI
  alias Hearth.IAM
  alias Hearth.Instance
  alias Hearth.Moderation
  alias Hearth.Roles
  alias Hearth.RTC
  alias Hearth.TranscriptionPolicy
  alias Hearth.Vault
  alias Oban.Telemetry

  @impl Application
  def start(_type, _args) do
    Confex.resolve_env!(:hearth)
    :ok = Logger.add_handlers(:hearth)

    roles = Roles.load!()

    TranscriptionPolicy.load!()

    Instance.load()

    # A missing or wrong encryption key stops the app here, not at the first message
    :ok = Vault.load!()

    :ok = Telemetry.attach_default_logger()

    :ok = OpentelemetryEcto.setup([:hearth, :repo])
    :ok = OpentelemetryOban.setup()

    roles
    |> children()
    |> Supervisor.start_link(strategy: :one_for_one, name: Hearth.Supervisor)
  end

  @spec children([Roles.role()]) :: [
          Supervisor.child_spec() | module() | {module(), term()}
        ]
  def children(roles) do
    oban = Application.fetch_env!(:hearth, Oban)

    Roles.children(
      [
        {Hearth.Repo, :all},
        {Hearth.PubSub.Supervisor, :all},
        {{Oban, Keyword.update!(oban, :queues, &Roles.queues(&1, roles))}, :all},
        {{Task, &IAM.cache_specs/0}, :all},
        {{DNSCluster, query: Application.get_env(:hearth, :dns_cluster_query) || :ignore}, :all}
      ] ++
        Enum.map(Roles.cluster_children(), &{&1, :all}) ++
        [
          {%{id: RTC, start: {:pg, :start_link, [RTC.scope()]}}, :all},
          {Hearth.Accounts.Supervisor, [:web]},
          {Hearth.Notifications.Supervisor, [:web]},
          {Hearth.Media.Supervisor, [:web]},
          {Hearth.Media.LinkPreviews, [:web]},
          {Hearth.Forum.Supervisor, [:web]},
          {Hearth.Chat.Supervisor, [:web]},
          {Hearth.Events.Supervisor, [:web]},
          {Hearth.RTC.Supervisor, [:rtc]},
          {Hearth.Voice.Supervisor, [:rtc]},
          {Hearth.Voice.Listener.Communities, [:rtc]}
        ] ++ Enum.map(Moderation.servings() ++ AI.servings(), &{&1, [:ai]}),
      roles
    )
  end
end
