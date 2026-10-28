defmodule Hearth.Auth.EmailChangeConfirmed do
  alias Hearth.Common.T

  @derive {Inspect, except: [:undo_token]}
  @fields ~w[user_id old_email new_email undo_token ttl]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          user_id: T.id(),
          old_email: T.email(),
          new_email: T.email(),
          undo_token: String.t(),
          ttl: pos_integer()
        }
end
