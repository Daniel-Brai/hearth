defmodule Hearth.Events.EventLibrary do
  # Same as each template's event in the web app's domain/catalog.ts

  @events %{
    "club" => %{title: "First hangout", days: 7, mins: 60, repeat: :none},
    "local" => %{title: "First meetup planning call", days: 5, mins: 45, repeat: :none},
    "creator" => %{title: "Live Q&A", days: 10, mins: 60, repeat: :none},
    "class" => %{title: "Weekly study session", days: 3, mins: 90, repeat: :weekly},
    "support" => %{title: "Weekly check in", days: 6, mins: 60, repeat: :weekly},
    "oss" => %{title: "Office hours", days: 7, mins: 60, repeat: :weekly}
  }

  @spec for_template(String.t()) :: nil | map()
  def for_template(template), do: Map.get(@events, template)
end
