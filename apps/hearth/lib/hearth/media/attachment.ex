defmodule Hearth.Media.Attachment do
  use Hearth.Repo.Schema, prefix: "media"

  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Media.Asset

  @owners ~w[post reply message]a

  schema "attachments" do
    field :position, :integer
    field :post_id, Ecto.UUID
    field :reply_id, Ecto.UUID
    field :message_id, Ecto.UUID

    belongs_to :media, Asset

    timestamps(updated_at: false)
  end

  @type t :: %__MODULE__{
          id: T.id(),
          position: integer(),
          post_id: nil | T.id(),
          reply_id: nil | T.id(),
          message_id: nil | T.id(),
          media_id: T.id()
        }
  @type owner :: :post | :reply | :message

  @spec owner_field(owner()) :: :post_id | :reply_id | :message_id
  def owner_field(:post), do: :post_id
  def owner_field(:reply), do: :reply_id
  def owner_field(:message), do: :message_id

  @spec of(owner(), [T.id()]) :: [t()]
  def of(owner, ids) when owner in @owners and is_list(ids) do
    field = owner_field(owner)

    __MODULE__
    |> where([a], field(a, ^field) in ^ids)
    |> order_by([a], asc: a.position)
    |> preload(:media)
    |> Repo.all()
  end

  @spec delete_of(owner(), T.id()) :: :ok
  def delete_of(owner, id) when owner in @owners and is_binary(id) do
    field = owner_field(owner)

    __MODULE__
    |> where([a], field(a, ^field) == ^id)
    |> Repo.delete_all()

    :ok
  end

  @spec insert_all(owner(), T.id(), [T.id()]) :: :ok
  def insert_all(owner, id, media_ids) when owner in @owners and is_binary(id) do
    now = DateTime.utc_now()
    field = owner_field(owner)

    rows =
      media_ids
      |> Enum.with_index()
      |> Enum.map(fn {media_id, position} ->
        Map.put(
          %{id: Common.new_id(), media_id: media_id, position: position, inserted_at: now},
          field,
          id
        )
      end)

    Repo.insert_all(__MODULE__, rows)

    :ok
  end
end
