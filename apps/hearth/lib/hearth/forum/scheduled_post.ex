defmodule Hearth.Forum.ScheduledPost do
  use Hearth.Repo.Schema, prefix: "forum"

  import Ecto.Changeset
  import Ecto.Query
  import Hearth.Repo.Changeset, only: [validate_from_now: 3]

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Repo

  # Far enough ahead to be worth waiting for and no more than a month out
  @send_window [after: {1, :minute}, before: {30, :day}]

  @changeable ~w[kind_id title body attachment_ids send_at]a

  schema "scheduled_posts" do
    field :author_id, Ecto.UUID
    field :community_id, Ecto.UUID
    field :kind_id, Ecto.UUID
    field :title, :string
    field :body, :string, default: ""
    field :attachment_ids, {:array, Ecto.UUID}, default: []
    field :send_at, :utc_datetime_usec
    field :failure, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          author_id: T.id(),
          community_id: T.id(),
          kind_id: nil | T.id(),
          title: String.t(),
          body: String.t(),
          attachment_ids: [T.id()],
          send_at: DateTime.t(),
          failure: nil | String.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = scheduled, %{} = params) do
    scheduled
    |> cast(params, @changeable)
    |> update_change(:title, &String.trim/1)
    |> update_change(:body, &String.trim/1)
    |> validate_required(~w[title kind_id send_at]a)
    |> validate_from_now(:send_at, @send_window)
    |> validate_length(:title, max: 150)
    |> validate_length(:body, max: 40_000)
    |> validate_length(:attachment_ids, max: 10)
  end

  # A new time clears an earlier failure so it is tried again
  @spec reschedule_changeset(t(), DateTime.t()) :: Changeset.t()
  def reschedule_changeset(%__MODULE__{} = scheduled, %DateTime{} = send_at) do
    scheduled
    |> change(send_at: send_at, failure: nil)
    |> validate_from_now(:send_at, @send_window)
  end

  # The reason it couldn't go up, kept as a short code the app turns into words
  @spec fail(t(), atom() | Changeset.t()) :: {:ok, t()} | {:error, Changeset.t()}
  def fail(%__MODULE__{} = scheduled, %Changeset{}), do: fail(scheduled, :invalid)

  def fail(%__MODULE__{} = scheduled, reason) when is_atom(reason) do
    scheduled
    |> change(failure: Atom.to_string(reason))
    |> Repo.update()
  end

  @spec list_for(T.id()) :: [t()]
  def list_for(author_id) do
    __MODULE__
    |> where(author_id: ^author_id)
    |> order_by(:send_at)
    |> Repo.all()
  end

  @spec count_for(T.id()) :: non_neg_integer()
  def count_for(author_id) do
    __MODULE__
    |> where(author_id: ^author_id)
    |> Repo.aggregate(:count)
  end
end
