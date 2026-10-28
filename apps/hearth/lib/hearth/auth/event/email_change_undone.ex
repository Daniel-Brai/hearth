defmodule Hearth.Auth.EmailChangeUndone do
  alias Hearth.Common.T

  @fields [:user_id, :email]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          user_id: T.id(),
          email: T.email()
        }
end
