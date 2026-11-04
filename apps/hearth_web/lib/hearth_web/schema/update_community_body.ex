defmodule HearthWeb.Schema.UpdateCommunityBody do
  use JSV.Schema

  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias HearthWeb.Schema
  alias HearthWeb.Schema.Link

  defschema %{
    title: "UpdateCommunityBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      name: string(minLength: 2, maxLength: 60),
      tagline: nullable(string(maxLength: 120)),
      description: nullable(string(maxLength: 4_000)),
      hue: Schema.enum_of(Community, :hue),
      logo_id: nullable(uuid()),
      banner_id: nullable(uuid()),
      welcome_message: nullable(string(maxLength: 2_000)),
      visibility: Schema.enum_of(Community, :visibility),
      links: array_of(Link, maxItems: 10),
      categories:
        array_of(enum(Communities.list_category_slugs()),
          maxItems: 2,
          description: "Category slugs, at most two"
        )
    }
  }
end
