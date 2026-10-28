defmodule Hearth.Transcripts.Speaker do
  use Hearth.Repo.Schema, prefix: "transcripts"

  alias Hearth.Common.T

  schema "speakers" do
    field :transcript_id, Ecto.UUID
    field :user_id, Ecto.UUID
    field :speaker_index, :integer
    field :label, :string
    field :transcribed_at, :utc_datetime_usec

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          transcript_id: T.id(),
          user_id: nil | T.id(),
          speaker_index: non_neg_integer(),
          label: nil | String.t(),
          transcribed_at: nil | DateTime.t()
        }

  @spec ensure(struct()) :: {:ok, t()}
  def ensure(%__MODULE__{transcript_id: transcript_id, speaker_index: index} = speaker) do
    {:ok, _inserted} =
      Repo.insert(speaker,
        on_conflict: :nothing,
        conflict_target: [:transcript_id, :speaker_index]
      )

    {:ok, get(transcript_id: transcript_id, speaker_index: index)}
  end
end
