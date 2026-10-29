defmodule HearthWeb.Schema.UpdateCommunityBody do
  use JSV.Schema

  alias Hearth.Communities
  alias HearthWeb.Schema.Link

  defschema %{
    title: "UpdateCommunityBody",
    type: :object,
    additionalProperties: false,
    properties: %{
      name: string(minLength: 2, maxLength: 60),
      tagline: nullable(string(maxLength: 120)),
      description: nullable(string(maxLength: 4_000)),
      hue: enum(~w[ink blue violet purple pink red orange yellow green aqua]),
      logo_id: nullable(uuid()),
      banner_id: nullable(uuid()),
      welcome_message: nullable(string(maxLength: 2_000)),
      visibility: enum(~w[public_indexed public invite_only private]),
      links: array_of(Link, maxItems: 10),
      categories:
        array_of(enum(Communities.list_category_slugs()),
          maxItems: 2,
          description: "Category slugs, at most two"
        )
    }
  }
end
