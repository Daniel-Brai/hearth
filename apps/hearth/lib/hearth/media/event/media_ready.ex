defmodule Hearth.Media.MediaReady do
  use Hearth.PubSub.WebsocketEvent

  alias Hearth.Common.T

  @fields [:media_id, :uploader_id]
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{media_id: T.id(), uploader_id: T.id()}

  @impl Hearth.PubSub.WebsocketEvent
  def broadcast_on(%__MODULE__{uploader_id: id}), do: "user:#{id}"
end
