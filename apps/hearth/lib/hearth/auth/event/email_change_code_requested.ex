defmodule Hearth.Auth.EmailChangeCodeRequested do
  alias Hearth.Common.T

  @derive {Inspect, except: [:code]}
  @fields ~w[user_id email code ttl]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          user_id: T.id(),
          email: T.email(),
          code: String.t(),
          ttl: pos_integer()
        }
end
