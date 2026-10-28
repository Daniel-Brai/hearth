defmodule Hearth.RTC do
  use Boundary, deps: [Hearth.Roles], exports: [Peer, Recorder, Supervisor, Turn]

  alias Hearth.Common.T
  alias Hearth.Roles
  alias Hearth.RTC.Peer
  alias Hearth.RTC.Turn

  @scope __MODULE__

  @spec scope() :: atom()
  def scope, do: @scope

  @spec join(term()) :: :ok
  def join(group), do: :pg.join(@scope, group, self())

  @spec members(term()) :: [pid()]
  def members(group), do: :pg.get_members(@scope, group)

  @spec peers(term()) :: [pid()]
  def peers(session_id) do
    for {:peer, ^session_id, _user} = group <- :pg.which_groups(@scope),
        peer <- members(group),
        do: peer
  end

  @spec start_peer(keyword()) :: DynamicSupervisor.on_start_child()
  def start_peer(opts) do
    opts = Keyword.put(opts, :config, config())
    partition = {:via, PartitionSupervisor, {Hearth.RTC.PeerSupervisor, self()}}

    DynamicSupervisor.start_child(partition, {Peer, opts})
  end

  @spec pick_node() :: nil | node()
  def pick_node do
    load = :peers |> members() |> Enum.frequencies_by(&node/1)

    :rtc
    |> Roles.nodes()
    |> Enum.min_by(&Map.get(load, &1, 0), fn -> nil end)
  end

  # Empty without a TURN server, which a server with a public IP doesn't need
  @spec ice_servers(T.id()) :: [Turn.ice_server()]
  def ice_servers(user_id), do: Turn.ice_servers(user_id, config())

  @spec available?() :: boolean()
  def available? do
    config()[:public_ip] != nil and :rtc in Roles.in_cluster()
  end

  @spec config() :: keyword()
  def config do
    config = Application.fetch_env!(:hearth, __MODULE__)

    config
    |> Keyword.update(:public_ip, nil, &parse_ip/1)
    |> Keyword.update(:port_range, [0], &parse_range/1)
  end

  defp parse_ip(nil), do: nil
  defp parse_ip(""), do: nil

  defp parse_ip(value) when is_binary(value) do
    {:ok, ip} = value |> String.trim() |> String.to_charlist() |> :inet.parse_address()
    ip
  end

  defp parse_range(nil), do: [0]
  defp parse_range(""), do: [0]

  defp parse_range(value) when is_binary(value) do
    [first, last] =
      value |> String.split("-") |> Enum.map(&(&1 |> String.trim() |> String.to_integer()))

    first..last
  end

  defp parse_range(%Range{} = range), do: range
end
