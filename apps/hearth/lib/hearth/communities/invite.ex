defmodule Hearth.Communities.Invite do
  use Hearth.Repo.Schema, prefix: "communities"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Communities.Community
  alias Hearth.Communities.InviteEmail

  @changeable ~w[max_uses expires_at role_key]a

  schema "invites" do
    field :code, :string
    field :role_key, :string, default: "member"
    field :max_uses, :integer
    field :uses_count, :integer, default: 0
    field :expires_at, :utc_datetime_usec
    field :revoked_at, :utc_datetime_usec
    field :created_by_id, Ecto.UUID

    belongs_to :community, Community
    has_many :emails, InviteEmail

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          code: String.t(),
          role_key: String.t(),
          max_uses: nil | integer(),
          uses_count: integer(),
          expires_at: nil | DateTime.t(),
          revoked_at: nil | DateTime.t(),
          created_by_id: nil | T.id(),
          community_id: T.id()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = invite, %{} = params) do
    invite
    |> cast(params, @changeable)
    |> put_code()
    |> validate_required([:code, :role_key])
    |> validate_number(:max_uses, greater_than: 0)
    |> unique_constraint(:code)
  end

  @spec unusable(t()) :: nil | :revoked | :expired | :used_up
  def unusable(%__MODULE__{} = invite) do
    cond do
      invite.revoked_at ->
        :revoked

      invite.expires_at != nil and DateTime.before?(invite.expires_at, DateTime.utc_now()) ->
        :expired

      invite.max_uses != nil and invite.uses_count >= invite.max_uses ->
        :used_up

      true ->
        nil
    end
  end

  # Ten characters of an unguessable code, readable aloud so no 0/O or 1/l
  @alphabet ~c"23456789abcdefghijkmnpqrstuvwxyz"

  defp put_code(%Changeset{data: %{code: nil}} = changeset) do
    code =
      for <<byte <- :crypto.strong_rand_bytes(10)>>,
        into: "",
        do: <<Enum.at(@alphabet, rem(byte, 32))>>

    put_change(changeset, :code, code)
  end

  defp put_code(changeset), do: changeset

  @spec links(T.id()) :: [t()]
  def links(community_id) do
    emailed = from(e in InviteEmail, where: e.invite_id == parent_as(:invite).id)

    query =
      from(i in __MODULE__,
        as: :invite,
        where: i.community_id == ^community_id and not exists(emailed),
        order_by: [desc: i.inserted_at],
        limit: 20
      )

    Repo.all(query)
  end

  @spec revoke(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def revoke(%__MODULE__{} = invite) do
    invite
    |> change(revoked_at: DateTime.utc_now())
    |> Repo.update()
  end

  @spec count_use(t()) :: :ok
  def count_use(%__MODULE__{id: id}) do
    __MODULE__
    |> where(id: ^id)
    |> Repo.update_all(inc: [uses_count: 1])

    :ok
  end
end
