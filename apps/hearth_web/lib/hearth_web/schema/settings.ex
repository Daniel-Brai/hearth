defmodule HearthWeb.Schema.Settings do
  use JSV.Schema

  alias Hearth.Accounts
  alias HearthWeb.Schema

  defschema %{
    title: "Settings",
    type: :object,
    required: ~w[
      theme
      ui_sounds
      play_sounds
      haptics
      captions_on
      compact_feeds
      sidebar_collapsed
      tour_done
      key_bindings
      notification_prefs
      digest
    ]a,
    additionalProperties: false,
    properties: %{
      theme: Schema.enum_of(Accounts.Settings, :theme),
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
      digest: Schema.enum_of(Accounts.Settings, :digest)
    }
  }
end
