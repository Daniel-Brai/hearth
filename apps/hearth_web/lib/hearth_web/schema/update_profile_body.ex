defmodule HearthWeb.Schema.UpdateProfileBody do
  use JSV.Schema

  alias HearthWeb.Schema.Link
  alias HearthWeb.Schema.Privacy

  defschema %{
    title: "UpdateProfileBody",
    type: :object,
    description: "Only the fields sent change, send null to clear one",
    additionalProperties: false,
    properties: %{
      display_name: nullable(string(minLength: 1, maxLength: 50)),
      bio: nullable(string(maxLength: 300)),
      pronouns: nullable(string(maxLength: 40)),
      location: nullable(string(maxLength: 80)),
      timezone: nullable(string(maxLength: 64)),
      links:
        array_of(Link,
          maxItems: 20,
          description: "Replaces the links, in order"
        ),
      privacy: %{
        type: :object,
        description: "Only the choices sent change",
        additionalProperties: false,
        properties: Privacy.json_schema().properties
      },
      avatar_id: nullable(uuid(description: "Null removes the photo"))
    }
  }
end
