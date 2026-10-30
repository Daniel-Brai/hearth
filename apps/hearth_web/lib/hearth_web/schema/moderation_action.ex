defmodule HearthWeb.Schema.ModerationAction do
  use JSV.Schema

  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "ModerationAction",
    type: :object,
    description:
      "Metadata has from and to for a level change, expires_at for a ban or session_id for a voice host action",
    required: ~w[id action subject_type subject_id reason metadata actor target inserted_at]a,
    properties: %{
      id: uuid(),
      action: enum(~w[
        removed
        restored
        kept
        banned
        unbanned
        server_muted
        server_mute_lifted
        disconnected
        moved_to_listeners
        recording_started
        recording_stopped
        pinned
        locked
        changed
      ]),
      subject_type: enum(~w[post reply message user community room]),
      subject_id: uuid(),
      reason: nullable(string()),
      metadata: %{type: :object},
      actor: nullable(UserSummary),
      target: nullable(UserSummary),
      inserted_at: string(format: :"date-time")
    }
  }
end
