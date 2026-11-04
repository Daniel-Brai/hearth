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

  operation :subscribe_push,
    summary: "Send pushes to this device",
    description: "Saving a device again moves it to whoever is signed in on it now",
    security: [%{"bearer" => []}],
    request_body: Schema.PushSubscriptionBody,
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "endpoint" => ~V[required|string|max:2000],
    "p256dh" => ~V[required|string|max:100],
    "auth" => ~V[required|string|max:100]
  }

  def subscribe_push(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    attrs = %{
      endpoint: params["endpoint"],
      p256dh: params["p256dh"],
      auth: params["auth"],
      user_agent: conn |> get_req_header("user-agent") |> List.first()
    }

    with true <- Notifications.push_enabled?(),
         {:ok, _subscription} <- Notifications.link_push_sub(auth, attrs) do
      send_resp(conn, :no_content, "")
    else
      false -> {:error, :push_off}
      error -> error
    end
  end

  operation :unsubscribe_push,
    summary: "Stop sending pushes to this device",
    security: [%{"bearer" => []}],
    request_body: Schema.PushEndpointBody,
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"endpoint" => ~V[required|string|max:2000]}

  def unsubscribe_push(%Conn{assigns: %{auth: %{}}} = conn, %{"endpoint" => endpoint}) do
    %Conn{assigns: %{auth: auth}} = conn

    :ok = Notifications.unlink_push_sub(auth, endpoint)
    send_resp(conn, :no_content, "")
  end
end
