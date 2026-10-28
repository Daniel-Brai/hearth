defmodule Hearth.Events.EventReminder do
  alias Hearth.Common.T

  @fields ~w[event_id community_id starts_at minutes user_ids]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          event_id: T.id(),
          community_id: T.id(),
          starts_at: DateTime.t(),
          minutes: pos_integer(),
          user_ids: [T.id()]
        }
end
