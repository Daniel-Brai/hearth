defmodule HearthWeb.Schema.InstanceUpdate do
  use JSV.Schema

  defschema %{
    title: "InstanceUpdate",
    type: :object,
    required: ~w[enabled current_version latest_version update_available release_name
                 release_url notes published_at checked_at]a,
    properties: %{
      enabled: boolean(description: "False when UPDATE_CHECK=false turned the daily check off"),
      current_version: string(),
      latest_version: nullable(string(description: "Null before the first check")),
      update_available: boolean(),
      release_name: nullable(string()),
      release_url: nullable(string()),
      notes: nullable(string(description: "Markdown, cut to 2,000 characters")),
      published_at: nullable(string(format: :"date-time")),
      checked_at: nullable(string(format: :"date-time"))
    }
  }
end
