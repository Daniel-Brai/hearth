defmodule Hearth.Media.Asset do
  use Hearth.Repo.Schema, prefix: "media"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Media.FileType
  alias Hearth.Media.Lifecycle
  alias Hearth.Media.Variant

  @statuses ~w[uploading processing ready held blocked failed]a
  @purposes ~w[attachment avatar logo]a
  @fields ~w[idempotency_key name purpose content_type byte_size sha256 duration_ms]a

  schema "assets" do
    field :uploader_id, Ecto.UUID
    field :idempotency_key, :string
    field :name, :string
    field :purpose, Ecto.Enum, values: @purposes, default: :attachment
    field :bucket_key, :string
    field :content_type, :string
    field :byte_size, :integer
    field :sha256, :string
    field :multipart_upload_id, :string
    field :width, :integer
    field :height, :integer
    field :duration_ms, :integer
    field :blurhash, :string
    field :status, Ecto.Enum, values: @statuses, default: :uploading
    field :failure, :string

    embeds_many :variants, Variant, on_replace: :delete

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          uploader_id: nil | T.id(),
          idempotency_key: String.t(),
          name: String.t(),
          purpose: :attachment | :avatar | :logo,
          bucket_key: String.t(),
          content_type: String.t(),
          byte_size: integer(),
          sha256: String.t(),
          multipart_upload_id: nil | String.t(),
          width: nil | integer(),
          height: nil | integer(),
          duration_ms: nil | integer(),
          blurhash: nil | String.t(),
          status: status(),
          failure: nil | String.t(),
          variants: [Variant.t()]
        }
  @type status :: :uploading | :processing | :ready | :held | :blocked | :failed

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = media, %{} = params) do
    media
    |> cast(params, @fields)
    |> validate_required(@fields -- [:purpose, :duration_ms])
    |> validate_length(:idempotency_key, min: 8, max: 128)
    |> validate_length(:name, max: 255)
    |> validate_inclusion(:content_type, FileType.content_types(),
      message: "is not a type that can be uploaded"
    )
    |> validate_number(:byte_size, greater_than: 0)
    |> validate_max_size()
    |> validate_max_duration()
    |> update_change(:sha256, &String.downcase/1)
    |> validate_change(:sha256, &valid_sha256/2)
    |> unique_constraint([:uploader_id, :idempotency_key])
  end

  @spec key(t() | T.id(), String.t()) :: String.t()
  def key(%__MODULE__{id: id}, name), do: key(id, name)
  def key(id, name) when is_binary(id), do: "media/#{id}/#{name}"

  @spec prefix(t()) :: String.t()
  def prefix(%__MODULE__{id: id}), do: "media/#{id}"

  @spec advance(t(), atom(), keyword()) :: {:ok, t()} | {:error, :invalid_transition | :stale}
  def advance(%__MODULE__{} = media, event, changes \\ []) do
    with {:ok, status} <- Lifecycle.next(media, event) do
      transition(media, media.status, [{:status, status} | changes])
    end
  end

  # Does nothing if the row already moved on so a retried job can't undo another
  @spec transition(t(), status(), keyword()) :: {:ok, t()} | {:error, :stale}
  def transition(%__MODULE__{id: id}, status, changes) do
    query = from(m in __MODULE__, where: m.id == ^id and m.status == ^status, select: m)

    case Repo.update_all(query, set: [{:updated_at, DateTime.utc_now()} | changes]) do
      {1, [media]} -> {:ok, media}
      {0, []} -> {:error, :stale}
    end
  end

  @spec upload_counts(T.id(), DateTime.t()) ::
          %{unfinished: non_neg_integer(), recent: non_neg_integer()}
  def upload_counts(uploader_id, %DateTime{} = since) do
    query =
      from m in __MODULE__,
        where: m.uploader_id == ^uploader_id,
        select: %{
          unfinished: filter(count(), m.status == ^:uploading),
          recent: filter(count(), m.inserted_at > ^since)
        }

    Repo.one(query)
  end

  @spec unfinished_before(DateTime.t(), pos_integer()) :: [t()]
  def unfinished_before(%DateTime{} = before, limit) do
    query =
      from m in __MODULE__,
        where: m.status == ^:uploading and m.inserted_at < ^before,
        order_by: m.inserted_at,
        limit: ^limit

    Repo.all(query)
  end

  defp validate_max_size(changeset) do
    max = changeset |> get_field(:content_type) |> FileType.max_bytes()

    case max do
      nil -> changeset
      max -> validate_number(changeset, :byte_size, less_than_or_equal_to: max)
    end
  end

  # The client says how long a video is so a long one is refused before upload
  defp validate_max_duration(changeset) do
    type = get_field(changeset, :content_type)

    case FileType.kind(type) do
      :video ->
        validate_number(changeset, :duration_ms,
          greater_than: 0,
          less_than_or_equal_to: FileType.max_video_ms()
        )

      _other ->
        changeset
    end
  end

  defp valid_sha256(field, value) do
    case byte_size(value) == 64 and match?({:ok, _bytes}, Base.decode16(value, case: :lower)) do
      true -> []
      false -> [{field, "is not a SHA-256 in hex"}]
    end
  end
end
