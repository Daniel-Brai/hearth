defmodule HearthWeb.PushSubscriptionController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules

  alias Hearth.Notifications
  alias Plug.Conn

  tags ["Notifications"]

  operation :create,
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

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
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

  operation :delete,
    summary: "Stop sending pushes to this device",
    security: [%{"bearer" => []}],
    request_body: Schema.PushEndpointBody,
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"endpoint" => ~V[required|string|max:2000]}

  def delete(%Conn{assigns: %{auth: %{}}} = conn, %{"endpoint" => endpoint}) do
    %Conn{assigns: %{auth: auth}} = conn

    :ok = Notifications.unlink_push_sub(auth, endpoint)
    send_resp(conn, :no_content, "")
  end
end
