defmodule Hearth.Auth.SignedIn do
  alias Hearth.Common.T

  @fields [:user_id, :method]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          user_id: T.id(),
          method: :code | :github | :google
        }
end
