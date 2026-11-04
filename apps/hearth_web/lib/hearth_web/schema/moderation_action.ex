defmodule HearthWeb.Schema.ModerationAction do
  use JSV.Schema

  alias Hearth.Moderation.Action
  alias HearthWeb.Schema
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "ModerationAction",
    type: :object,
    description:
      "Metadata has from and to for a level change, expires_at for a ban or session_id for a voice host action",
    required: ~w[id action subject_type subject_id reason metadata actor target inserted_at]a,
    properties: %{
      id: uuid(),
      action: Schema.enum_of(Action, :action),
      subject_type: Schema.enum_of(Action, :subject_type),
      subject_id: uuid(),
      reason: nullable(string()),
      metadata: %{type: :object},
      actor: nullable(UserSummary),
      target: nullable(UserSummary),
      inserted_at: string(format: :"date-time")
    }
  }
end
