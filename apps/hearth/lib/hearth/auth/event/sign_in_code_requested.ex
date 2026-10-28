defmodule Hearth.Auth.SignInCodeRequested do
  alias Hearth.Common.T

  @derive {Inspect, except: [:code]}
  @fields ~w[email code ttl]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          email: T.email(),
          code: String.t(),
          ttl: pos_integer()
        }
end
