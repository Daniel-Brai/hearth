defmodule HearthWeb.Schema.ModerationLevel do
  use JSV.Schema

  defschema %{
    title: "ModerationLevel",
    type: :object,
    description: "Level is null when a room follows its community, effective is what applies",
    required: [:level, :effective],
    properties: %{
      level: nullable(enum(~w[full reports none])),
      effective: enum(~w[full reports none])
    }
  }
end
