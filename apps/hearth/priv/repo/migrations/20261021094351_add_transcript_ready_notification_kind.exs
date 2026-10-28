defmodule Hearth.Repo.Migrations.AddTranscriptReadyNotificationKind do
  use Ecto.Migration

  @old "('reply', 'mention', 'dm', 'answer', 'event_scheduled', 'event_reminder', 'live_started', 'invite', 'report')"
  @new "('reply', 'mention', 'dm', 'answer', 'event_scheduled', 'event_reminder', 'live_started', 'invite', 'report', 'transcript_ready')"

  def up, do: replace_kinds(@new)
  def down, do: replace_kinds(@old)

  defp replace_kinds(kinds) do
    execute "ALTER TABLE notifications.notifications DROP CONSTRAINT kind"
    execute "ALTER TABLE notifications.notifications ADD CONSTRAINT kind CHECK (kind IN #{kinds})"
  end
end
