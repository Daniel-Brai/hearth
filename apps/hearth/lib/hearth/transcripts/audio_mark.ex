defmodule Hearth.Transcripts.AudioMark do
  use Hearth.Repo.Schema, prefix: "transcripts"

  alias Hearth.Common.T

  # Shorter pauses are part of how people talk
  @gap_ms 2_000

  schema "audio_marks" do
    field :transcript_id, Ecto.UUID
    field :recording_id, Ecto.UUID
    field :kind, Ecto.Enum, values: [:silence, :filler]
    field :start_ms, :integer
    field :end_ms, :integer
    field :label, :string
    field :removed, :boolean, default: false

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          transcript_id: T.id(),
          recording_id: T.id(),
          kind: :silence | :filler,
          start_ms: non_neg_integer(),
          end_ms: non_neg_integer(),
          label: nil | String.t(),
          removed: boolean()
        }

  @spec silences([%{start_ms: integer(), end_ms: integer()}], non_neg_integer()) ::
          [{non_neg_integer(), non_neg_integer()}]
  def silences(segments, duration_ms) do
    {gaps, reached} =
      segments
      |> Enum.sort_by(& &1.start_ms)
      |> Enum.reduce({[], 0}, fn segment, {gaps, reached} ->
        {gap(gaps, reached, segment.start_ms), max(reached, segment.end_ms)}
      end)

    gaps
    |> gap(reached, duration_ms)
    |> Enum.reverse()
  end

  defp gap(gaps, from, to) when to - from > @gap_ms, do: [{from, to} | gaps]
  defp gap(gaps, _from, _to), do: gaps
end
