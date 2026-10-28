defmodule Hearth.Chat.Conversation do
  use Hearth.Repo.Schema, prefix: "chat"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Chat.ConversationMember
  alias Hearth.Common.T

  @changeable [:name]

  schema "conversations" do
    field :kind, Ecto.Enum, values: [:direct, :group]
    field :name, :string
    field :direct_key, :string
    field :created_by_id, Ecto.UUID

    has_many :members, ConversationMember

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          kind: :direct | :group,
          name: nil | String.t(),
          direct_key: nil | String.t(),
          created_by_id: nil | T.id()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = conversation, %{} = params) do
    conversation
    |> cast(params, @changeable)
    |> validate_length(:name, max: 60)
    |> unique_constraint(:direct_key)
  end

  @spec direct(String.t()) :: nil | t()
  def direct(direct_key), do: get(kind: :direct, direct_key: direct_key)

  @spec for_member(T.id()) :: [t()]
  def for_member(user_id) do
    __MODULE__
    |> join(:inner, [c], m in ConversationMember, on: m.conversation_id == c.id)
    |> where([_c, m], m.user_id == ^user_id)
    |> order_by([c], desc: c.updated_at)
    |> preload(:members)
    |> Repo.all()
  end
end
