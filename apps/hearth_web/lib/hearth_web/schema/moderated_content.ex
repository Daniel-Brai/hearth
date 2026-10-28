defmodule HearthWeb.Schema.ModeratedContent do
  use JSV.Schema

  defschema %{
    title: "ModeratedContent",
    type: :object,
    required: [:subject_type, :subject_id, :status],
    properties: %{
      subject_type: enum(~w[post reply message]),
      subject_id: uuid(),
      status: enum(~w[published pending removed])
    }
  }
end
