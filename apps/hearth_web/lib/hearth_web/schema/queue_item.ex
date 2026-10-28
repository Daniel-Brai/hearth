defmodule HearthWeb.Schema.QueueItem do
  use JSV.Schema

  alias HearthWeb.Schema.QueueReport
  alias HearthWeb.Schema.QueueSubject
  alias HearthWeb.Schema.UserSummary

  defschema %{
    title: "QueueItem",
    type: :object,
    description: "Subject is null once the content is deleted",
    required: ~w[
      id
      community_id
      room_id
      source
      status
      subject_type
      subject_id
      reason
      note
      score
      report_count
      reports
      subject
      author
      reviewed_by
      reviewed_at
      inserted_at
    ]a,
    properties: %{
      id: uuid(),
      community_id: nullable(uuid(description: "Null for a direct message")),
      room_id: nullable(uuid()),
      source: enum(~w[automatic report instance]),
      status: enum(~w[pending kept removed dismissed]),
      subject_type: enum(~w[post reply message]),
      subject_id: uuid(),
      reason: nullable(string()),
      note: nullable(string()),
      score: nullable(number(minimum: 0, maximum: 1)),
      report_count: non_neg_integer(),
      reports: array_of(QueueReport),
      subject: nullable(QueueSubject),
      author: nullable(UserSummary),
      reviewed_by: nullable(UserSummary),
      reviewed_at: nullable(string(format: :"date-time")),
      inserted_at: string(format: :"date-time")
    }
  }
end
