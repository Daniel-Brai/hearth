defmodule HearthWeb.Schema.KindInput do
  use JSV.Schema

  defschema %{
    title: "KindInput",
    type: :object,
    required: [:label, :icon, :hue],
    additionalProperties: false,
    properties: %{
      key: nullable(string(maxLength: 40, description: "Left out for a new kind")),
      label: string(maxLength: 30),
      icon: string(maxLength: 40),
      hue: string(maxLength: 20),
      description: nullable(string(maxLength: 300)),
      title_hint: nullable(string(maxLength: 120)),
      body_hint: nullable(string(maxLength: 2_000)),
      answers: boolean(),
      postable: boolean(description: "Announcements need post.pin")
    }
  }
end
