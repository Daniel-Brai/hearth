defmodule HearthWeb.RoomChannel do
  use HearthWeb, :channel

  alias Hearth.Chat
  alias Hearth.Common
  alias Hearth.Communities
  alias Phoenix.Socket

  @impl Phoenix.Channel
  def join("room:" <> id, _payload, socket) do
    %Socket{assigns: %{auth: auth}} = socket

    with true <- Common.valid_id?(id),
         {:ok, room} <- Communities.get_room(id: id),
         true <- Chat.can_read?(auth, room) do
      {:ok, socket}
    else
      _denied -> {:error, %{reason: "unauthorized"}}
    end
  end
end
