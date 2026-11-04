defmodule HearthWeb.Schema.Notification do
  use JSV.Schema

  alias Hearth.Notifications
  alias HearthWeb.Schema
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "Notification",
    type: :object,
    required: ~w[id kind actor community_id subject_type subject_id data read_at inserted_at]a,
    properties: %{
      id: uuid(),
      kind: Schema.enum_of(Notifications.Notification, :kind),
      actor: nullable(UserSummary),
      community_id: nullable(uuid()),
      subject_type: string(),
      subject_id: uuid(),
      data: %{
        type: :object,
        description: "Names and ids for the text and link"
      },
      read_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time")
    }
  }
end
