defmodule HearthWeb.Typing do
  alias Hearth.Chat
  alias HearthWeb.FloodGuard
  alias Phoenix.Socket

  # The browser sends at most one a few seconds apart, and stops it on its own after a pause
  @per_second 2

  @spec relay(Socket.t(), Chat.place(), boolean()) :: :ok
  def relay(%Socket{} = socket, place, typing) when is_boolean(typing) do
    %Socket{assigns: %{auth: auth}} = socket

    with {:allow, _count} <- FloodGuard.hit("typing:#{auth.id}", 1000, @per_second),
         true <- Chat.can_write?(auth, place) do
      Phoenix.Channel.broadcast_from!(socket, "typing", %{user_id: auth.id, typing: typing})
    end

    :ok
  end
end
