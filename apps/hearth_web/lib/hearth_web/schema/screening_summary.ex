defmodule HearthWeb.Schema.ScreeningSummary do
  use JSV.Schema

  defschema %{
    title: "ScreeningSummary",
    type: :object,
    description: "Many kept holds mean the threshold is too low",
    required: [:threshold, :days],
    properties: %{
      threshold: number(),
      days:
        array_of(%{
          type: :object,
          required: ~w[day screened held kept removed]a,
          properties: %{
            day: string(format: :date),
            screened: integer(minimum: 0),
            held: integer(minimum: 0),
            kept: integer(minimum: 0),
            removed: integer(minimum: 0)
          }
        })
    }
  }
end
