defmodule HearthWeb.Schema.UpdateSettingsBody do
  use JSV.Schema

  defschema %{
    title: "UpdateSettingsBody",
    type: :object,
    description: "Only the settings sent change",
    additionalProperties: false,
    properties: %{
      theme: enum(~w[system light dark]),
      ui_sounds: boolean(),
      play_sounds: boolean(),
      haptics: boolean(),
      captions_on: boolean(),
      compact_feeds: boolean(),
      sidebar_collapsed: boolean(),
      tour_done: boolean(),
      key_bindings: %{
        type: :object,
        additionalProperties: string()
      },
      notification_prefs: %{
        type: :object,
        additionalProperties: boolean()
      },
      digest: enum(~w[daily weekly off])
    }
  }
end
