defmodule HearthWeb.NotificationController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Notifications
  alias HearthWeb.Avatars
  alias HearthWeb.Paging
  alias Plug.Conn

  tags ["Notifications"]

  operation :index,
    summary: "List my notifications",
    description: "Newest first, with the unread count",
    security: [%{"bearer" => []}],
    parameters: Schema.paging(),
    responses: [
      ok: {Schema.NotificationPage, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"limit" => ~V[between:1,50], "after" => ~V[string], "before" => ~V[string]}

  def index(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    with %{data: notifications} = page <-
           Notifications.list_notifications(auth, Paging.opts(conn)) do
      actors =
        notifications
        |> Enum.map(& &1.actor_id)
        |> Enum.reject(&is_nil/1)
        |> Accounts.list_users()
        |> Avatars.put_urls()
        |> Map.new(&{&1.id, &1})

      render(conn, :index, page: page, actors: actors, unread: Notifications.unread_count(auth))
    end
  end

  operation :read,
    summary: "Mark a notification read",
    security: [%{"bearer" => []}],
    parameters: [id: [in: :path, schema: %{type: :string, format: :uuid}]],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def read(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    :ok = Notifications.mark_read(auth, id)

    send_resp(conn, :no_content, "")
  end

  operation :read_all,
    summary: "Mark every notification read",
    security: [%{"bearer" => []}],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def read_all(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    :ok = Notifications.mark_all_read(auth)

    send_resp(conn, :no_content, "")
  end
end
