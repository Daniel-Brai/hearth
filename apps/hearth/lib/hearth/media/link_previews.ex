defmodule Hearth.Media.LinkPreviews do
  use GenServer

  alias Hearth.Media.Command.BuildLinkPreview
  alias Hearth.Media.LinkPreview

  # Each node keeps good previews a while so a busy chat fetches a link once, and never keeps failures
  @found_ms :timer.hours(6)
  @sweep_ms :timer.minutes(10)
  @max_entries 10_000

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @spec get(String.t()) :: {:ok, LinkPreview.t()} | {:error, :not_found}
  def get(url) when is_binary(url) do
    now = System.monotonic_time(:millisecond)

    case :ets.lookup(__MODULE__, url) do
      [{^url, preview, expires_at}] when expires_at > now -> {:ok, preview}
      _stale -> url |> BuildLinkPreview.execute() |> keep(url, now)
    end
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(__MODULE__, [:named_table, :public, read_concurrency: true, write_concurrency: true])
    Process.send_after(self(), :sweep, @sweep_ms)
    {:ok, nil}
  end

  @impl GenServer
  def handle_info(:sweep, state) do
    now = System.monotonic_time(:millisecond)
    :ets.select_delete(__MODULE__, [{{:_, :_, :"$1"}, [{:"=<", :"$1", now}], [true]}])

    # Past the cap everything goes, which costs a refetch and never unbounded memory
    if :ets.info(__MODULE__, :size) > @max_entries, do: :ets.delete_all_objects(__MODULE__)

    Process.send_after(self(), :sweep, @sweep_ms)
    {:noreply, state}
  end

  defp keep({:ok, %LinkPreview{} = preview}, url, now) do
    :ets.insert(__MODULE__, {url, preview, now + @found_ms})
    {:ok, preview}
  end

  defp keep({:error, _reason}, _url, _now), do: {:error, :not_found}
end
