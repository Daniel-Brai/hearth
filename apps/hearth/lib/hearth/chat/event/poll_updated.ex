defmodule Hearth.Chat.PollUpdated do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  # Carries the new totals so a busy room redraws without asking again. Who voted never leaves the server
  @fields ~w[poll_id message_id room_id voters counts closed_at]a
  @enforce_keys @fields
  defstruct @fields

  @type count :: %{option_id: T.id(), votes: non_neg_integer()}

  @type t :: %__MODULE__{
          poll_id: T.id(),
          message_id: T.id(),
          room_id: T.id(),
          voters: non_neg_integer(),
          counts: [count()],
          closed_at: nil | DateTime.t()
        }

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{room_id: id}), do: "room:#{id}"
end
