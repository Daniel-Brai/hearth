defmodule Hearth.RTC.Recorder do
  # Packets are stored undecoded as <<at_ms::32, size::32, packet::binary>>

  alias ExRTP.Packet
  alias Hearth.Common.T

  @type recording :: %{id: T.id(), t0: integer()}
  @type segment :: %{file: :file.io_device(), t0: integer()}
  @type stretch :: %{
          user_id: T.id(),
          kind: :audio | :video,
          path: Path.t(),
          offset_ms: non_neg_integer(),
          duration_ms: non_neg_integer()
        }

  @spec dir(T.id()) :: Path.t()
  def dir(recording_id), do: Path.join([System.tmp_dir!(), "hearth-recordings", recording_id])

  # The folder comes from a recording id and the name from a user id, both
  # set by the server
  # sobelow_skip ["Traversal.FileModule"]
  @spec open(recording(), T.id(), :audio | :video) :: {:ok, segment()} | {:error, term()}
  def open(%{id: id, t0: t0}, user_id, kind) when kind in [:audio, :video] do
    dir = dir(id)
    name = "#{user_id}.#{kind}.#{System.unique_integer([:positive, :monotonic])}.rtp"
    path = Path.join(dir, name)
    modes = [:raw, :binary, :append, {:delayed_write, 64_000, 1_000}]

    with :ok <- File.mkdir_p(dir),
         {:ok, file} <- :file.open(path, modes) do
      {:ok, %{file: file, t0: t0}}
    end
  end

  @spec write(segment(), Packet.t()) :: :ok | {:error, term()}
  def write(%{file: file, t0: t0}, %Packet{} = packet) do
    at = max(System.system_time(:millisecond) - t0, 0)
    data = Packet.encode(packet)

    :file.write(file, <<at::32, byte_size(data)::32, data::binary>>)
  end

  @spec close(segment()) :: :ok
  def close(%{file: file}) do
    _closed = :file.close(file)
    :ok
  end

  @spec stretches(Path.t()) :: [stretch()]
  def stretches(dir) do
    case File.ls(dir) do
      {:ok, names} ->
        names
        |> Enum.flat_map(&stretch(dir, &1))
        |> Enum.sort_by(& &1.offset_ms)

      {:error, _reason} ->
        []
    end
  end

  defp stretch(dir, name) do
    path = Path.join(dir, name)

    with [user_id, kind, _n, "rtp"] <- String.split(name, "."),
         {:ok, kind} <- kind(kind),
         {first, last} <- span(path) do
      [%{user_id: user_id, kind: kind, path: path, offset_ms: first, duration_ms: last - first}]
    else
      _other -> []
    end
  end

  defp kind("audio"), do: {:ok, :audio}
  defp kind("video"), do: {:ok, :video}
  defp kind(_other), do: :error

  # The times of the first and last packet, skipping over the packets
  # themselves
  defp span(path) do
    reduce_headers(path, nil, fn
      at, nil -> {at, at}
      at, {first, _last} -> {first, at}
    end)
  end

  defp reduce_headers(path, acc, fun) do
    {:ok, file} = :file.open(path, ~w[raw binary read read_ahead]a)

    try do
      skim(file, acc, fun)
    after
      :file.close(file)
    end
  end

  defp skim(file, acc, fun) do
    with {:ok, <<at::32, size::32>>} <- :file.read(file, 8),
         {:ok, _position} <- :file.position(file, {:cur, size}) do
      skim(file, fun.(at, acc), fun)
    else
      _end -> acc
    end
  end

  # A packet cut short at the end by a crash is left out
  @spec reduce(Path.t(), acc, (non_neg_integer(), Packet.t(), acc -> acc)) :: acc when acc: term()
  def reduce(path, acc, fun) do
    {:ok, file} = :file.open(path, [:raw, :binary, :read, {:read_ahead, 256_000}])

    try do
      read_packets(file, acc, fun)
    after
      :file.close(file)
    end
  end

  defp read_packets(file, acc, fun) do
    with {:ok, <<at::32, size::32>>} <- :file.read(file, 8),
         {:ok, <<data::binary-size(^size)>>} <- :file.read(file, size) do
      acc =
        case Packet.decode(data) do
          {:ok, packet} -> fun.(at, packet, acc)
          {:error, _reason} -> acc
        end

      read_packets(file, acc, fun)
    else
      _end -> acc
    end
  end
end
