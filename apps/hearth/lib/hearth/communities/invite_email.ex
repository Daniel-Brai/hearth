defmodule Hearth.Communities.InviteEmail do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset
  import Hearth.Repo.Changeset

  alias Ecto.Changeset
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Communities.Invite
  alias Hearth.Vault

  @fields ~w[email status sent_at accepted_at]a
  @changeable @fields -- [:email]

  schema "invite_emails" do
    # Sealed at rest so email_hash finds it and keeps it unique per invite
    field :email, Vault.Binary
    field :email_hash, :binary
    field :status, Ecto.Enum, values: ~w[pending accepted declined revoked]a, default: :pending
    field :sent_at, :utc_datetime_usec
    field :accepted_at, :utc_datetime_usec

    belongs_to :invite, Invite

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          email: String.t(),
          email_hash: binary(),
          status: :pending | :accepted | :declined | :revoked,
          sent_at: nil | DateTime.t(),
          accepted_at: nil | DateTime.t(),
          invite_id: T.id()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = invite_email, %{} = params) do
    invite_email
    |> cast(params, @fields)
    |> update_change(:email, &Common.normalize/1)
    |> validate_required([:email])
    |> validate_email(:email)
    |> put_email_hash()
    |> unique_constraint([:invite_id, :email_hash], error_key: :email)
  end

  @spec for_community(T.id()) :: [t()]
  def for_community(community_id) do
    query =
      from(e in __MODULE__,
        join: i in assoc(e, :invite),
        where: i.community_id == ^community_id,
        order_by: [desc: e.inserted_at],
        limit: 100,
        preload: [invite: i]
      )

    Repo.all(query)
  end

  @spec pending_for(String.t()) :: [t()]
  def pending_for(email) do
    query =
      from(e in __MODULE__,
        join: i in assoc(e, :invite),
        join: c in assoc(i, :community),
        where: e.email_hash == ^digest(email) and e.status == :pending and is_nil(c.archived_at),
        order_by: [desc: e.inserted_at],
        preload: [invite: {i, community: c}]
      )

    Repo.all(query)
  end

  @spec accept(T.id(), String.t()) :: :ok
  def accept(invite_id, email) do
    __MODULE__
    |> where(invite_id: ^invite_id, email_hash: ^digest(email), status: :pending)
    |> Repo.update_all(set: [status: :accepted, accepted_at: DateTime.utc_now()])

    :ok
  end

  defp put_email_hash(%Changeset{valid?: true, changes: %{email: email}} = changeset),
    do: put_change(changeset, :email_hash, digest(email))

  defp put_email_hash(changeset), do: changeset

  defp digest(email), do: email |> Common.normalize() |> Vault.hash()
end
