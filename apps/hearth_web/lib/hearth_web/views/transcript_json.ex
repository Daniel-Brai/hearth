defmodule HearthWeb.TranscriptJSON do
  alias HearthWeb.RecordingJSON
  alias HearthWeb.UserJSON

  @fields ~w[id session_id recording_id community_id post_id status failure language duration_ms ready_at]a

  def show(%{view: view, room: room, people: people, editable: editable}) do
    %{transcript: transcript, recording: recording, session: session} = view

    transcript
    |> Map.take(@fields)
    |> Map.merge(%{
      room_id: room.id,
      room_name: room.name,
      topic: session.topic,
      started_at: session.started_at,
      speakers: Enum.map(transcript.speakers, &speaker/1),
      segments: Enum.map(transcript.segments, &segment(&1, editable)),
      silences:
        for(
          mark <- transcript.audio_marks,
          mark.kind == :silence and not mark.removed,
          do: %{start_ms: mark.start_ms, end_ms: mark.end_ms}
        ),
      people: people |> Map.values() |> Enum.map(&UserJSON.summary/1),
      recording: RecordingJSON.show(%{recording: recording})
    })
  end

  def update_segment(%{segment: segment}), do: segment(segment, MapSet.new([segment.speaker_id]))

  defp speaker(speaker) do
    %{
      id: speaker.id,
      index: speaker.speaker_index,
      user_id: speaker.user_id,
      label: speaker.label
    }
  end

  defp segment(segment, editable) do
    %{
      id: segment.id,
      speaker_id: segment.speaker_id,
      start_ms: segment.start_ms,
      end_ms: segment.end_ms,
      text: segment.text,
      edited: segment.edited_at != nil,
      editable: MapSet.member?(editable, segment.speaker_id)
    }
  end
end
