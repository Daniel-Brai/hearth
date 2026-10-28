defmodule Hearth.Transcripts.Segment do
  use Hearth.Repo.Schema, prefix: "transcripts"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @max_text 5_000

  schema "segments" do
    field :transcript_id, Ecto.UUID
    field :speaker_id, Ecto.UUID
    field :start_ms, :integer
    field :end_ms, :integer
    field :text, :string
    field :words, {:array, :map}
    field :edited_by_id, Ecto.UUID
    field :edited_at, :utc_datetime_usec

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          transcript_id: T.id(),
          speaker_id: T.id(),
          start_ms: non_neg_integer(),
          end_ms: non_neg_integer(),
          text: String.t(),
          words: nil | [map()],
          edited_by_id: nil | T.id(),
          edited_at: nil | DateTime.t()
        }

  @spec edit_changeset(t(), T.id(), map()) :: Changeset.t()
  def edit_changeset(%__MODULE__{} = segment, user_id, %{} = params) do
    segment
    |> cast(params, [:text])
    |> update_change(:text, &trim/1)
    |> validate_required([:text])
    |> validate_length(:text, max: @max_text)
    |> put_change(:edited_by_id, user_id)
    |> put_change(:edited_at, DateTime.utc_now())
  end

  @spec edit(t(), T.id(), map()) :: {:ok, t()} | {:error, Changeset.t()}
  def edit(%__MODULE__{} = segment, user_id, %{} = params) do
    segment
    |> edit_changeset(user_id, params)
    |> Repo.update()
  end

  defp trim(nil), do: nil
  defp trim(text), do: String.trim(text)
end
