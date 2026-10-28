defmodule HearthWeb.Schema.PostKind do
  use JSV.Schema

  defschema %{
    title: "PostKind",
    type: :object,
    required:
      ~w[id key label icon hue description title_hint body_hint answers postable position]a,
    properties: %{
      id: uuid(),
      key: string(),
      label: string(),
      icon: string(),
      hue: string(),
      description: nullable(string()),
      title_hint: nullable(string()),
      body_hint: nullable(string()),
      answers: boolean(),
      postable: boolean(description: "Announcements need post.pin"),
      position: integer()
    }
  }
end
