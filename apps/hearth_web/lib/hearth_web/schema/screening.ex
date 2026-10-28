defmodule HearthWeb.Schema.Screening do
  use JSV.Schema

  defschema %{
    title: "Screening",
    type: :object,
    required: [:enabled, :image_floor],
    properties: %{
      enabled: boolean(),
      image_floor: boolean(description: "Every image is screened, whatever each community picked")
    }
  }
end
