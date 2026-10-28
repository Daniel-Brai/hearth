defmodule Hearth.Transcripts.Command.SaveSpeaker do
  import Ecto.Query, only: [from: 2]

  alias Ecto.Changeset
  alias Hearth.AI.Transcriber
  alias Hearth.Common
  alias Hearth.Repo
  alias Hearth.Transcripts.Segment
  alias Hearth.Transcripts.Speaker

  # Postgres takes at most 65535 values in one statement
  @batch 1_000

  # A second run replaces what the first wrote, so a retry never doubles lines
  @spec execute(Speaker.t(), [Transcriber.segment()]) ::
          {:ok, Speaker.t()} | {:error, Changeset.t()}
  def execute(%Speaker{} = speaker, segments) when is_list(segments) do
    now = DateTime.utc_now()

    rows =
      Enum.map(segments, fn segment ->
        Map.merge(Map.take(segment, ~w[start_ms end_ms text]a), %{
          id: Common.new_id(),
          transcript_id: speaker.transcript_id,
          speaker_id: speaker.id,
          inserted_at: now,
          updated_at: now
        })
      end)

    Repo.transact(fn ->
      Repo.delete_all(from(s in Segment, where: s.speaker_id == ^speaker.id))

      rows
      |> Enum.chunk_every(@batch)
      |> Enum.each(&Repo.insert_all(Segment, &1))

      speaker
      |> Changeset.change(transcribed_at: now)
      |> Repo.update()
    end)
  end
end
