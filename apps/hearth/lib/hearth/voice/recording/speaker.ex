defmodule Hearth.Voice.Recording.Speaker do
  use Ecto.Schema
  alias Hearth.Common.T

  @primary_key false

  embedded_schema do
    field :user_id, Ecto.UUID
    field :key, :string
  end

  @type t :: %__MODULE__{user_id: T.id(), key: String.t()}
end
