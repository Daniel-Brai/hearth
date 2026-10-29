defmodule HearthWeb.Schema.RoomSettings do
  use JSV.Schema

  defschema %{
    title: "RoomSettings",
    type: :object,
    required: ~w[link_previews sounds_enabled sounds_mode sounds_role_ids sounds_user_ids]a,
    additionalProperties: false,
    properties: %{
      link_previews: boolean(description: "Show link cards under messages"),
      sounds_enabled: boolean(description: "Off stops /play for everyone"),
      sounds_mode: enum(~w[everyone roles people], description: "Who can use /play"),
      sounds_role_ids:
        array_of(uuid(), maxItems: 50, description: "The roles who can when the mode is roles"),
      sounds_user_ids:
        array_of(uuid(), maxItems: 200, description: "The people who can when the mode is people")
    }
  }
end
