defmodule HearthWeb.Schema.UpdateInstanceBody do
  use JSV.Schema

  alias Hearth.Communities.InstanceSettings
  alias HearthWeb.Schema

  defschema %{
    title: "UpdateInstanceBody",
    type: :object,
    required: [:community_creation],
    additionalProperties: false,
    properties: %{
      community_creation: Schema.enum_of(InstanceSettings, :creation)
    }
  }
end
