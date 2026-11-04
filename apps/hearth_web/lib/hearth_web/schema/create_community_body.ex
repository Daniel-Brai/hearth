defmodule HearthWeb.Schema.CreateCommunityBody do
  use JSV.Schema

  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias HearthWeb.Schema

  defschema %{
    title: "CreateCommunityBody",
    type: :object,
    required: [:name],
    additionalProperties: false,
    properties: %{
      name: string(minLength: 2, maxLength: 60),
      tagline: nullable(string(maxLength: 120)),
      description: nullable(string(maxLength: 2_000)),
      logo_id: nullable(uuid(description: "An uploaded image, left out of a request")),
      hue: Schema.enum_of(Community, :hue),
      visibility: Schema.enum_of(Community, :visibility),
      template: enum(Communities.template_ids()),
      note: nullable(string(maxLength: 1_000)),
      categories:
        array_of(enum(Communities.list_category_slugs()),
          maxItems: 2,
          description: "Category slugs, at most two"
        )
    }
  }
end
