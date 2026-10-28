defmodule Hearth.Communities.InvitesEmailed do
  alias Hearth.Common.T

  @fields ~w[community_id community_name inviter_id inviter_name note invites]a
  @enforce_keys @fields
  defstruct @fields

  @type invite :: %{email: T.email(), code: String.t()}

  @type t :: %__MODULE__{
          community_id: T.id(),
          community_name: String.t(),
          inviter_id: T.id(),
          inviter_name: String.t(),
          note: nil | String.t(),
          invites: [invite()]
        }
end
