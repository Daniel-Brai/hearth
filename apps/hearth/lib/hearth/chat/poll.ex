defmodule Hearth.Chat.Poll do
  use Hearth.Repo.Schema, prefix: "chat"

  import Ecto.Changeset
  import Ecto.Query
  import Hearth.Repo.Changeset, only: [validate_from_now: 3]

  alias Ecto.Changeset
  alias Hearth.Chat.PollOption
  alias Hearth.Common.T
  alias Hearth.Repo

  # A poll set to close by itself runs for at least a minute and at most a week
  @close_window [after: {1, :minute}, before: {7, :day}]

  @changeable [:multiple, :closes_at]

  schema "polls" do
    field :message_id, Ecto.UUID
    field :room_id, Ecto.UUID
    field :multiple, :boolean, default: false
    field :closes_at, :utc_datetime_usec
    field :closed_at, :utc_datetime_usec

    has_many :options, PollOption, preload_order: [asc: :position]

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          message_id: T.id(),
          room_id: T.id(),
          multiple: boolean(),
          closes_at: nil | DateTime.t(),
          closed_at: nil | DateTime.t(),
          options: [PollOption.t()] | Ecto.Association.NotLoaded.t()
        }

  # Choices come as a list of labels and keep the order they were given in
  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = poll, %{} = params) do
    labels = params |> Map.get(:options, []) |> Enum.map(&String.trim/1)

    poll
    |> cast(params, @changeable)
    |> validate_from_now(:closes_at, @close_window)
    |> put_assoc(:options, Enum.with_index(labels, &%PollOption{label: &1, position: &2}))
    |> validate_choices(labels)
  end

  @spec open?(t()) :: boolean()
  def open?(%__MODULE__{closed_at: nil, closes_at: nil}), do: true

  def open?(%__MODULE__{closed_at: nil} = poll),
    do: DateTime.after?(poll.closes_at, DateTime.utc_now())

  def open?(%__MODULE__{}), do: false

  @spec close(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def close(%__MODULE__{} = poll) do
    poll
    |> change(closed_at: DateTime.utc_now())
    |> Repo.update()
  end

  @spec for_messages([T.id()]) :: [t()]
  def for_messages(message_ids) when is_list(message_ids) do
    __MODULE__
    |> where([p], p.message_id in ^message_ids)
    |> preload(:options)
    |> Repo.all()
  end

  defp validate_choices(changeset, labels) do
    changeset
    |> check(length(labels) in 2..10, "must have 2 to 10 choices")
    |> check(Enum.all?(labels, &(&1 != "")), "can't have an empty choice")
    |> check(Enum.all?(labels, &(String.length(&1) <= 100)), "can be at most 100 characters each")
    |> check(distinct?(labels), "must all be different")
  end

  defp check(changeset, true, _message), do: changeset
  defp check(changeset, false, message), do: add_error(changeset, :options, message)

  defp distinct?(labels) do
    folded = Enum.map(labels, &String.downcase/1)
    Enum.uniq(folded) == folded
  end
end
