defmodule HearthWeb.Schema.MediaVariant do
  use JSV.Schema

  alias Hearth.Media.Variant
  alias HearthWeb.Schema

  defschema %{
    title: "MediaVariant",
    type: :object,
    required: ~w[width height format url]a,
    properties: %{
      width: pos_integer(),
      height: pos_integer(),
      format: Schema.enum_of(Variant, :format),
      url: string()
    }
  }
end
