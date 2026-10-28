defmodule HearthWeb.Schema.CommunityTemplate do
  use JSV.Schema

  defschema %{
    title: "CommunityTemplate",
    type: :object,
    required: ~w[id label icon description category kinds rooms voice event placeholder]a,
    properties: %{
      id: string(),
      label: string(),
      icon: string(),
      description: string(),
      category: nullable(string()),
      kinds: array_of(string()),
      rooms: array_of(string()),
      voice: nullable(string()),
      event:
        nullable(%{
          type: :object,
          description: "Days after the community starts",
          required: [:title, :days, :mins, :repeat],
          properties: %{
            title: string(),
            days: pos_integer(),
            mins: pos_integer(),
            repeat: enum(~w[none daily weekly biweekly monthly])
          }
        }),
      placeholder: %{
        type: :object,
        required: [:name, :tagline],
        properties: %{name: string(), tagline: string()}
      }
    }
  }
end
