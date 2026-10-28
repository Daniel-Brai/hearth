defmodule HearthWeb.Schema.Membership do
  use JSV.Schema

  alias Hearth.IAM

  # The permission names come from this file, so editing it rebuilds the enum.
  @external_resource Path.expand("../../../../hearth/priv/permissions.yml", __DIR__)

  defschema %{
    title: "Membership",
    type: :object,
    required: [:roles, :permissions, :joined_at],
    properties: %{
      roles:
        array_of(%{
          type: :object,
          required: [:key, :name, :color],
          properties: %{key: string(), name: string(), color: nullable(string())}
        }),
      permissions: array_of(enum(IAM.permissions())),
      joined_at: string(format: :"date-time")
    }
  }
end
