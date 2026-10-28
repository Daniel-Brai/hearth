defmodule Hearth.Accounts.UserCreated do
  alias Hearth.Common.T

  @fields ~w[user_id username email]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          user_id: T.id(),
          username: String.t(),
          email: String.t()
        }
end
