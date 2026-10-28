defmodule Hearth.Accounts.Taken do
  # False means certainly free, true means maybe taken

  use GenServer

  import Bitwise
  import Ecto.Query

  alias Hearth.Accounts
  alias Hearth.Accounts.EmailChanged
  alias Hearth.Accounts.User
  alias Hearth.Accounts.UserCreated
  alias Hearth.Common
  alias Hearth.Repo

  require Logger

  @filters [:username, :email]
  @min_capacity 100_000
  @false_positive_rate 0.01
  @rebuild_every :timer.hours(24)

  @type filter :: :username | :email

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @spec member?(filter(), String.t()) :: boolean()
  def member?(filter, value) when filter in @filters and is_binary(value) do
    key = Common.normalize(value)

    case :ets.lookup(__MODULE__, filter) do
      [{^filter, table, bits, hashes}] -> all_set?(table, bits, hashes, key)
      [] -> true
    end
  rescue
    # The filter was swapped out between reading it and reading its bits
    ArgumentError -> true
  end

  @impl GenServer
  def init(_opts) do
    :ets.new(__MODULE__, [:named_table, :protected, read_concurrency: true])
    :ok = Accounts.subscribe_to_pubsub()

    {:ok, nil, {:continue, :boot}}
  end

  @impl GenServer
  def handle_continue(:boot, state) do
    case Application.fetch_env!(:hearth, __MODULE__)[:rebuild_on_boot] do
      true ->
        handle_continue(:rebuild, state)

      false ->
        Enum.each(@filters, &swap(&1, empty(&1, @min_capacity)))
        Process.send_after(self(), :rebuild, @rebuild_every)

        {:noreply, state}
    end
  end

  def handle_continue(:rebuild, state) do
    rebuild_all()
    Process.send_after(self(), :rebuild, @rebuild_every)

    {:noreply, state}
  end

  @impl GenServer
  def handle_call(:rebuild, _from, state) do
    rebuild_all()

    {:reply, :ok, state}
  end

  @impl GenServer
  def handle_info(:rebuild, state), do: handle_continue(:rebuild, state)

  def handle_info(%UserCreated{username: username, email: email}, state) do
    add(:username, username)
    add(:email, email)

    {:noreply, state}
  end

  def handle_info(%EmailChanged{email: email}, state) do
    add(:email, email)

    {:noreply, state}
  end

  def handle_info(_message, state), do: {:noreply, state}

  defp rebuild_all do
    count = Repo.aggregate(User, :count)
    capacity = max(count * 2, @min_capacity)

    Enum.each(@filters, &rebuild(&1, capacity))
  rescue
    error in [DBConnection.ConnectionError, DBConnection.OwnershipError, Postgrex.Error] ->
      Logger.warning("Taken filters not rebuilt: #{Exception.message(error)}")
  end

  defp rebuild(filter, capacity) do
    {^filter, table, bits, hashes} = entry = empty(filter, capacity)

    {:ok, :ok} =
      Repo.transaction(
        fn ->
          User
          |> select([user], field(user, ^filter))
          |> Repo.stream()
          |> Enum.each(&set_bits(table, bits, hashes, Common.normalize(&1)))
        end,
        timeout: :infinity
      )

    swap(filter, entry)
  end

  defp empty(filter, capacity) do
    bits = bit_count(capacity)
    table = :ets.new(:taken_bits, [:protected, read_concurrency: true])

    {filter, table, bits, hash_count(bits, capacity)}
  end

  defp swap(filter, entry) do
    previous = :ets.lookup(__MODULE__, filter)
    :ets.insert(__MODULE__, entry)

    for {^filter, table, _bits, _hashes} <- previous, do: :ets.delete(table)
  end

  defp add(filter, value) do
    case :ets.lookup(__MODULE__, filter) do
      [{^filter, table, bits, hashes}] -> set_bits(table, bits, hashes, Common.normalize(value))
      [] -> :ok
    end
  end

  defp set_bits(table, bits, hashes, key) do
    for position <- positions(key, bits, hashes) do
      index = div(position, 64)
      word = word_at(table, index)

      :ets.insert(table, {index, bor(word, 1 <<< rem(position, 64))})
    end
  end

  defp all_set?(table, bits, hashes, key) do
    key
    |> positions(bits, hashes)
    |> Enum.all?(fn position ->
      word = word_at(table, div(position, 64))
      band(word, 1 <<< rem(position, 64)) != 0
    end)
  end

  defp word_at(table, index) do
    case :ets.lookup(table, index) do
      [{^index, word}] -> word
      [] -> 0
    end
  end

  # Double hashing with two halves of one BLAKE2b digest
  defp positions(key, bits, hashes) do
    <<first::64, second::64, _rest::binary>> = :crypto.hash(:blake2b, key)

    for i <- 0..(hashes - 1), do: rem(first + i * second, bits)
  end

  defp bit_count(capacity) do
    ln2 = :math.log(2)

    ceil(-capacity * :math.log(@false_positive_rate) / (ln2 * ln2))
  end

  defp hash_count(bits, capacity), do: max(1, round(bits / capacity * :math.log(2)))
end
