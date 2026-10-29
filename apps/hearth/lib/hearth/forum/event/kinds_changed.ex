defmodule Hearth.Forum.KindsChanged do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields [:community_id]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{community_id: T.id()}

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{community_id: id}), do: "community:#{id}"
end
