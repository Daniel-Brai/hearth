defmodule Hearth.Communities.CommunityCreated do
  alias Hearth.Common.T

  @fields ~w[community_id owner_id template]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          community_id: T.id(),
          owner_id: T.id(),
          template: String.t()
        }
end
