defmodule Hearth.Communities.MemberBanned do
  alias Hearth.Common.T

  @fields ~w[community_id user_id banned_by_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          community_id: T.id(),
          user_id: T.id(),
          banned_by_id: T.id()
        }
end
