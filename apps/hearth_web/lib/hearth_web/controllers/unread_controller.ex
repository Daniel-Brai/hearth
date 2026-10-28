defmodule HearthWeb.UnreadController do
  use HearthWeb, :api_controller

  alias Hearth.Chat
  alias Plug.Conn

  tags ["Chat"]

  operation :show,
    summary: "Count my unread messages",
    description: "Per room in my communities and per conversation",
    security: [%{"bearer" => []}],
    responses: [
      ok: {Schema.Unread, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def show(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    render(conn, :show, unread: Chat.unread_counts(auth))
  end
end
