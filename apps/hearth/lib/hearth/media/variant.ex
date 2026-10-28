defmodule Hearth.Media.Variant do
  use Ecto.Schema

  @primary_key false

  embedded_schema do
    field :width, :integer
    field :height, :integer
    field :format, Ecto.Enum, values: ~w[webp avif mp4]a
    field :key, :string
  end

  @type t :: %__MODULE__{
          width: pos_integer(),
          height: pos_integer(),
          format: :webp | :avif | :mp4,
          key: String.t()
        }
end
