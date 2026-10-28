defmodule Hearth.Auth.TransferCodeRequested do
  alias Hearth.Common.T

  @derive {Inspect, except: [:code]}
  @fields ~w[user_id email community_name code ttl]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          user_id: T.id(),
          email: T.email(),
          community_name: String.t(),
          code: String.t(),
          ttl: pos_integer()
        }
end
