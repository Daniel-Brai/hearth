defmodule HearthWeb.Schema.UpdateSettingsBody do
  use JSV.Schema

  alias Hearth.Accounts.Settings
  alias HearthWeb.Schema

  defschema %{
    title: "UpdateSettingsBody",
    type: :object,
    description: "Only the settings sent change",
    additionalProperties: false,
    properties: %{
      theme: Schema.enum_of(Settings, :theme),
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
      digest: Schema.enum_of(Settings, :digest)
    }
  }
end
