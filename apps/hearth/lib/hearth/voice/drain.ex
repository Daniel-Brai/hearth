defmodule Hearth.Voice.Drain do
  # Sessions still live after the drain limit end as lost, and their people rejoin on another node

  use GenServer

  alias Hearth.Roles
  alias Hearth.Voice.Live

  require Logger

  @check_every 5_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec child_spec(keyword()) :: Supervisor.child_spec()
  def child_spec(opts) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      shutdown: limit() + @check_every
    }
  end

  @impl GenServer
  def init(_opts) do
    Process.flag(:trap_exit, true)
    {:ok, nil}
  end

  @impl GenServer
  def terminate(_reason, _state) do
    :ok = Roles.withdraw(:rtc)
    deadline = System.monotonic_time(:millisecond) + limit()

    Logger.info("Draining voice sessions before stopping")
    wait(deadline)
  end

  defp wait(deadline) do
    lives = DynamicSupervisor.which_children(Hearth.Voice.LiveSupervisor)

    cond do
      lives == [] ->
        :ok

      System.monotonic_time(:millisecond) >= deadline ->
        for {_id, pid, _type, _modules} <- lives, is_pid(pid), do: Live.lose(pid)
        :ok

      true ->
        Process.sleep(@check_every)
        wait(deadline)
    end
  end

  defp limit,
    do: :hearth |> Application.fetch_env!(Hearth.Voice) |> Keyword.fetch!(:drain_limit_ms)
end
