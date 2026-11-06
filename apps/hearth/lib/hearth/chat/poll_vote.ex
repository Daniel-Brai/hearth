defmodule Hearth.Chat.PollVote do
  use Hearth.Repo.Schema, prefix: "chat", primary_key: false

  import Ecto.Query

  alias Hearth.Common.T
  alias Hearth.Repo

  schema "poll_votes" do
    field :option_id, Ecto.UUID, primary_key: true
    field :user_id, Ecto.UUID, primary_key: true
    field :poll_id, Ecto.UUID

    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{option_id: T.id(), user_id: T.id(), poll_id: T.id()}

  # A new answer takes the place of the old one, and no options takes the vote back
  @spec replace(T.id(), T.id(), [T.id()]) :: {:ok, non_neg_integer()}
  def replace(poll_id, user_id, option_ids) do
    now = DateTime.utc_now()

    rows =
      Enum.map(
        option_ids,
        &%{option_id: &1, user_id: user_id, poll_id: poll_id, inserted_at: now}
      )

    Repo.transact(fn ->
      _taken_back = Repo.delete_all(where(__MODULE__, poll_id: ^poll_id, user_id: ^user_id))
      {count, nil} = Repo.insert_all(__MODULE__, rows)
      {:ok, count}
    end)
  end

  @spec counts([T.id()]) :: %{T.id() => pos_integer()}
  def counts(poll_ids) do
    __MODULE__
    |> where([v], v.poll_id in ^poll_ids)
    |> group_by([v], v.option_id)
    |> select([v], {v.option_id, count()})
    |> Repo.all()
    |> Map.new()
  end

  @spec voters([T.id()]) :: %{T.id() => pos_integer()}
  def voters(poll_ids) do
    __MODULE__
    |> where([v], v.poll_id in ^poll_ids)
    |> group_by([v], v.poll_id)
    |> select([v], {v.poll_id, count(v.user_id, :distinct)})
    |> Repo.all()
    |> Map.new()
  end

  @spec picked_by([T.id()], T.id()) :: %{T.id() => [T.id()]}
  def picked_by(poll_ids, user_id) do
    __MODULE__
    |> where([v], v.poll_id in ^poll_ids and v.user_id == ^user_id)
    |> select([v], {v.poll_id, v.option_id})
    |> Repo.all()
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
  end
end
