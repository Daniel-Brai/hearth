defmodule Hearth.Accounts.AvatarChanged do
  alias Hearth.Common.T

  @fields ~w[user_id previous_avatar_id avatar_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          user_id: T.id(),
          previous_avatar_id: nil | T.id(),
          avatar_id: nil | T.id()
        }
end
