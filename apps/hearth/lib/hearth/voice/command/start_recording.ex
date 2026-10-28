defmodule Hearth.Voice.Command.StartRecording do
  alias Hearth.Common.T
  alias Hearth.Events
  alias Hearth.Events.Event
  alias Hearth.Moderation.Action
  alias Hearth.Repo
  alias Hearth.Voice.Recording
  alias Hearth.Voice.Session

  @spec execute(Session.t(), T.id()) :: {:ok, Recording.t()} | {:error, :already_recording}
  def execute(%Session{} = session, actor_id) do
    recording = %Recording{
      session_id: session.id,
      community_id: session.community_id,
      room_id: session.room_id,
      started_by_id: actor_id,
      title: title(session)
    }

    Repo.transact(fn ->
      with {:ok, recording} <- Recording.start(recording),
           {:ok, _action} <- log(recording, actor_id, :recording_started, %{}) do
        {:ok, recording}
      end
    end)
  end

  # Named after the room's event when one is on, otherwise the session's topic
  defp title(%Session{event_id: nil} = session) do
    case Events.happening_in(session.community_id, session.room_id) do
      %Event{title: title} -> title
      nil -> session.topic
    end
  end

  defp title(%Session{event_id: id} = session) do
    case Events.get_event(id: id) do
      {:ok, event} -> event.title
      {:error, :not_found} -> session.topic
    end
  end

  @doc false
  @spec log(Recording.t(), T.id(), Action.action(), map()) ::
          {:ok, Action.t()} | {:error, Ecto.Changeset.t()}
  def log(recording, actor_id, action, metadata) do
    action = %Action{
      community_id: recording.community_id,
      actor_id: actor_id,
      action: action,
      subject_type: :room,
      subject_id: recording.room_id
    }

    metadata =
      Map.merge(metadata, %{session_id: recording.session_id, recording_id: recording.id})

    Action.insert(action, %{metadata: metadata})
  end
end
