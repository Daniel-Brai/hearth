defmodule HearthWeb.Schema.Event do
  alias HearthWeb.Schema.Event

  @events [
    Event.MessageCreated,
    Event.MessageEdited,
    Event.MessageReacted,
    Event.MessageRemoved,
    Event.SoundPlayed,
    Event.ContentRemoved,
    Event.ContentRestored,
    Event.PostCreated,
    Event.PostReacted,
    Event.ReplyCreated,
    Event.AnswerMarked,
    Event.KindsChanged,
    Event.MemberJoined,
    Event.MemberLeft,
    Event.RoomChanged,
    Event.RoomActivity,
    Event.MediaReady,
    Event.MediaFailed,
    Event.EventScheduled,
    Event.EventUpdated,
    Event.EventCancelled,
    Event.NotificationCreated,
    Event.VoiceSessionStarted,
    Event.VoiceSessionEnded,
    Event.VoiceAttendance,
    Event.VoiceParticipantChanged,
    Event.VoiceShareChanged,
    Event.VoiceSpeakingChanged,
    Event.VoiceRecordingChanged,
    Event.VoiceRecordingDeleted,
    Event.VoiceRecordingRenamed,
    Event.VoiceReaction,
    Event.VoiceCaption,
    Event.TranscriptReady
  ]

  @spec all() :: [module()]
  def all, do: @events

  @spec components() :: %{String.t() => module()}
  def components do
    Map.new(@events, fn schema -> {schema.json_schema().title, schema} end)
  end
end
