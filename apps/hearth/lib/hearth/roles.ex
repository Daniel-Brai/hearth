defmodule Hearth.Roles do
  use Boundary, deps: [], exports: []

  @type role :: :web | :rtc | :media | :ai

  @roles ~w[web rtc media ai]a
  @default ~w[web media ai]a
  @key {__MODULE__, :roles}
  @scope __MODULE__
  @announcer Module.concat(__MODULE__, Announcer)

  # A queue missing here stops the boot so no queue goes unworked
  @queues %{
    default: :web,
    mail: :web,
    digests: :web,
    push: :web,
    media: :media,
    video: :media,
    exports: :media,
    ai: :ai,
    transcribe: :ai
  }

  @spec all() :: [role()]
  def all, do: @roles

  @spec default() :: [role()]
  def default, do: @default

  @spec parse!(nil | String.t() | [String.t() | atom()]) :: [role()]
  def parse!(nil), do: @default

  def parse!(value) when is_binary(value), do: value |> String.split(",") |> parse!()

  def parse!([]),
    do: raise(ArgumentError, "HEARTH_ROLES is empty. Give one or more of #{list_names(@roles)}")

  def parse!(values) when is_list(values) do
    names =
      values
      |> Enum.map(&(&1 |> to_string() |> String.trim() |> String.downcase()))
      |> Enum.reject(&(&1 == ""))

    known = Map.new(@roles, &{Atom.to_string(&1), &1})

    case Enum.reject(names, &Map.has_key?(known, &1)) do
      [] when names == [] ->
        @default

      [] ->
        Enum.filter(@roles, &(Atom.to_string(&1) in names))

      unknown ->
        raise ArgumentError,
              "HEARTH_ROLES has #{list_names(unknown)}, which this release doesn't know. " <>
                "Use #{list_names(@roles)}"
    end
  end

  @spec load!() :: [role()]
  def load! do
    roles = :hearth |> Application.get_env(:roles) |> parse!()
    :persistent_term.put(@key, roles)

    roles
  end

  @spec list() :: [role()]
  def list, do: :persistent_term.get(@key, nil) || load!()

  @spec enabled?(role()) :: boolean()
  def enabled?(role) when role in @roles, do: role in list()

  @spec queues(keyword(pos_integer()), [role()]) :: keyword(pos_integer())
  def queues(queues, roles) do
    Enum.filter(queues, fn {queue, _limit} ->
      case Map.fetch(@queues, queue) do
        {:ok, role} -> role in roles
        :error -> raise ArgumentError, "the Oban queue #{inspect(queue)} has no role"
      end
    end)
  end

  @spec children([{Supervisor.child_spec() | module() | {module(), term()}, :all | [role()]}], [
          role()
        ]) :: [Supervisor.child_spec() | module() | {module(), term()}]
  def children(entries, roles) do
    for {child, wanted} <- entries, wanted == :all or Enum.any?(wanted, &(&1 in roles)) do
      child
    end
  end

  @spec cluster_children() :: [Supervisor.child_spec()]
  def cluster_children do
    [
      %{id: :pg, start: {:pg, :start_link, [@scope]}},
      %{id: __MODULE__, start: {__MODULE__, :start_announcer, []}}
    ]
  end

  # The group forgets the node when this process or the node goes away
  @doc false
  @spec start_announcer() :: Agent.on_start()
  def start_announcer do
    roles = list()

    Agent.start_link(fn -> for role <- roles, do: :ok = :pg.join(@scope, role, self()) end,
      name: @announcer
    )
  end

  @spec in_cluster() :: [role()]
  def in_cluster do
    Enum.filter(@roles, &(:pg.get_members(@scope, &1) != []))
  end

  @spec nodes(role()) :: [node()]
  def nodes(role) when role in @roles do
    @scope
    |> :pg.get_members(role)
    |> Enum.map(&node/1)
    |> Enum.uniq()
  end

  @spec withdraw(role()) :: :ok
  def withdraw(role) when role in @roles do
    case Process.whereis(@announcer) do
      nil -> :ok
      announcer -> Agent.get(announcer, fn _state -> :pg.leave(@scope, role, announcer) end)
    end

    :ok
  end

  defp list_names(roles), do: Enum.map_join(roles, ", ", &to_string/1)
end
