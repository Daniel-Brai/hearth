defmodule Hearth.Chat.ScheduledMessage do
  use Hearth.Repo.Schema, prefix: "chat"

  import Ecto.Changeset
  import Ecto.Query
  import Hearth.Repo.Changeset, only: [validate_send_at: 1]

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Repo
  alias Hearth.Vault

  @changeable ~w[body attachment_ids send_at]a

  schema "scheduled_messages" do
    field :author_id, Ecto.UUID
    field :room_id, Ecto.UUID
    field :conversation_id, Ecto.UUID
    field :body, Vault.Binary, default: ""
    field :attachment_ids, {:array, Ecto.UUID}, default: []
    field :send_at, :utc_datetime_usec
    field :failure, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          author_id: T.id(),
          room_id: nil | T.id(),
          conversation_id: nil | T.id(),
          body: String.t(),
          attachment_ids: [T.id()],
          send_at: DateTime.t(),
          failure: nil | String.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = scheduled, %{} = params) do
    scheduled
    |> cast(params, @changeable)
    |> update_change(:body, &String.trim/1)
    |> validate_required([:send_at])
    |> validate_send_at()
    |> validate_length(:body, max: 4_000)
    |> validate_length(:attachment_ids, max: 10)
    |> validate_not_command()
    |> validate_content()
  end

  # A new time clears an earlier failure so it is tried again
  @spec reschedule_changeset(t(), DateTime.t()) :: Changeset.t()
  def reschedule_changeset(%__MODULE__{} = scheduled, %DateTime{} = send_at) do
    scheduled
    |> change(send_at: send_at, failure: nil)
    |> validate_send_at()
  end

  # The reason it couldn't send, kept as a short code the app turns into words
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

  # A command runs the moment it is sent, so it has no later to wait for
  defp validate_not_command(changeset) do
    validate_change(changeset, :body, fn :body, body ->
      if String.starts_with?(body, "/"), do: [body: "can't be a command"], else: []
    end)
  end

  defp validate_content(changeset) do
    case {get_field(changeset, :body), get_field(changeset, :attachment_ids)} do
      {nil, []} -> add_error(changeset, :body, "can't be blank")
      _content -> changeset
    end
  end
end
