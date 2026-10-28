defmodule Hearth.Communities.OwnershipTransferred do
  alias Hearth.Common.T

  @fields ~w[community_id from_id to_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          community_id: T.id(),
          from_id: T.id(),
          to_id: T.id()
        }
end
