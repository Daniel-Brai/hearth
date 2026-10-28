defmodule Hearth.Notifications.InAppMessage do
  alias Hearth.Common.T

  @enforce_keys ~w[kind subject_type subject_id]a
  defstruct [:kind, :actor_id, :community_id, :subject_type, :subject_id, data: %{}]

  @type t :: %__MODULE__{
          kind: atom(),
          actor_id: nil | T.id(),
          community_id: nil | T.id(),
          subject_type: String.t(),
          subject_id: T.id(),
          data: map()
        }
end
