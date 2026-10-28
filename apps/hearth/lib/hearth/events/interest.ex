defmodule Hearth.Events.Interest do
  use Hearth.Repo.Schema, prefix: "events", primary_key: false

  alias Hearth.Common.T

  schema "event_interests" do
    field :event_id, Ecto.UUID, primary_key: true
    field :user_id, Ecto.UUID, primary_key: true
    field :reminded_at, :utc_datetime_usec

    timestamps()
  end

  @type t :: %__MODULE__{
          event_id: T.id(),
          user_id: T.id(),
          reminded_at: nil | DateTime.t()
        }

  @spec toggle(T.id(), T.id()) :: :interested | :not_interested
  def toggle(event_id, user_id) do
    case get(event_id: event_id, user_id: user_id) do
      nil ->
        __MODULE__
        |> struct!(event_id: event_id, user_id: user_id)
        |> Repo.insert!()

        :interested

      %__MODULE__{} = interest ->
        Repo.delete!(interest)
        :not_interested
    end
  end

  @spec user_ids(T.id()) :: [T.id()]
  def user_ids(event_id) do
    __MODULE__
    |> where(event_id: ^event_id)
    |> select([i], i.user_id)
    |> Repo.all()
  end

  @spec user_ids_by_event([T.id()]) :: %{T.id() => [T.id()]}
  def user_ids_by_event(event_ids) do
    __MODULE__
    |> where([i], i.event_id in ^event_ids)
    |> order_by([i], asc: i.inserted_at)
    |> select([i], {i.event_id, i.user_id})
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end

  @spec mark_reminded(T.id()) :: :ok
  def mark_reminded(event_id) do
    __MODULE__
    |> where(event_id: ^event_id)
    |> Repo.update_all(set: [reminded_at: DateTime.utc_now()])

    :ok
  end
end
