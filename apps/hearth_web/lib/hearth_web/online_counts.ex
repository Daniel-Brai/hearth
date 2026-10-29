defmodule HearthWeb.OnlineCounts do
  use GenServer

  alias Hearth.Accounts
  alias Hearth.Common.T
  alias Hearth.IAM
  alias HearthWeb.Endpoint
  alias HearthWeb.Presence
  alias Phoenix.Socket.Broadcast

  @app :hearth_web
  @every_ms Application.compile_env(@app, [__MODULE__, :every_ms], 3_000)
  @start Application.compile_env(@app, [__MODULE__, :start], true)

  # Each node pushes to its own sockets from its copy of presence, so no count is sent twice.
  # Tests start it themselves since it reads the database outside any test
  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    case Keyword.get(opts, :start, @start) do
      true -> GenServer.start_link(__MODULE__, opts, name: __MODULE__)
      false -> :ignore
    end
  end

  @spec count([T.id()]) :: %{T.id() => pos_integer()}
  def count(community_ids) when is_list(community_ids) do
    Presence.online_ids()
    |> Accounts.presence_shown()
    |> then(&IAM.member_counts(community_ids, &1))
  end

  @spec online_for(T.id()) :: [T.id()]
  def online_for(user_id) when is_binary(user_id) do
    Presence.online_ids()
    |> Accounts.presence_shown()
    |> IAM.sharing([user_id])
    |> Map.get(user_id, [])
  end

  @impl GenServer
  def init(_opts) do
    :ok = Presence.subscribe()
    {:ok, %{changed: MapSet.new(), timer: nil}}
  end

  # Joins and leaves gather until the timer fires, so a busy community gets one push at a time
  @impl GenServer
  def handle_info(%Broadcast{event: "presence_diff", payload: diff}, state) do
    changed = diff.joins |> Map.merge(diff.leaves) |> Map.keys() |> MapSet.new()
    timer = state.timer || Process.send_after(self(), :push, @every_ms)

    {:noreply, %{state | changed: MapSet.union(state.changed, changed), timer: timer}}
  end

  # A failed recount is logged and skipped, and never restarts this process
  def handle_info(:push, state) do
    changed = MapSet.to_list(state.changed)
    {:ok, _pid} = Task.Supervisor.start_child(__MODULE__.Tasks, fn -> push(changed) end)
    {:noreply, %{state | changed: MapSet.new(), timer: nil}}
  end

  defp push(user_ids) do
    :ok = push_counts(user_ids)
    :ok = push_people(user_ids)
  end

  defp push_counts(user_ids) do
    community_ids = IAM.shared_community_ids(user_ids)
    counts = count(community_ids)

    for id <- community_ids do
      payload = %{community_id: id, count: Map.get(counts, id, 0)}
      :ok = Endpoint.local_broadcast("community:" <> id, "online_count", payload)
    end

    :ok
  end

  # Only people who share a community hear about someone, and never about those who hide it
  defp push_people(user_ids) do
    online = Presence.online_ids()
    now = MapSet.new(online)

    user_ids
    |> Accounts.presence_shown()
    |> IAM.sharing(online)
    |> Enum.each(fn {viewer_id, ids} ->
      {on, off} = Enum.split_with(ids, &MapSet.member?(now, &1))
      payload = %{online: on, offline: off}
      :ok = Endpoint.local_broadcast("user:" <> viewer_id, "presence_changed", payload)
    end)
  end
end
