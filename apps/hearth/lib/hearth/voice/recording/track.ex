defmodule Hearth.Voice.Recording.Track do
  use Ecto.Schema
  alias Hearth.Common.T

  @primary_key false

  embedded_schema do
    field :user_id, Ecto.UUID
    field :kind, Ecto.Enum, values: [:audio, :video]
    field :key, :string
    field :offset_ms, :integer
    field :duration_ms, :integer
  end

  @type t :: %__MODULE__{
          user_id: T.id(),
          kind: :audio | :video,
          key: String.t(),
          offset_ms: non_neg_integer(),
          duration_ms: non_neg_integer()
        }
end
