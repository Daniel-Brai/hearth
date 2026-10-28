defmodule HearthWeb.InstanceController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Instance
  alias Plug.Conn

  tags ["Instance"]

  operation :show,
    summary: "Show what this instance has set up",
    description: "Needs no sign in",
    responses: [ok: {Schema.Instance, description: "OK"}]

  def show(conn, _params), do: render(conn, :show, settings: Instance.settings())

  operation :update,
    summary: "Change who may start a community",
    description: "For instance admins",
    security: [%{"bearer" => []}],
    request_body: Schema.UpdateInstanceBody,
    responses: [
      ok: {Schema.Instance, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_creation" => ~V[required|allowed:admins,request,anyone]}

  def update(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_creation" => mode} = params

    with :ok <- Communities.put_creation_mode(auth, Common.to_atom(mode)) do
      render(conn, :show, settings: Instance.settings())
    end
  end

  operation :update_status,
    summary: "Show whether a newer Hearth is out",
    description: "For instance admins, from the last daily check",
    security: [%{"bearer" => []}],
    responses: [
      ok: {Schema.InstanceUpdate, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def update_status(%Conn{assigns: %{auth: %{is_instance_admin: true}}} = conn, _params),
    do: render(conn, :update_status, status: Instance.update_status())

  def update_status(%Conn{}, _params), do: {:error, :forbidden}

  operation :check_update,
    summary: "Check GitHub for a newer Hearth now",
    description: "For instance admins",
    security: [%{"bearer" => []}],
    responses: [
      ok: {Schema.InstanceUpdate, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def check_update(%Conn{assigns: %{auth: %{is_instance_admin: true}}} = conn, _params) do
    case Instance.check_for_update() do
      {:ok, status} -> render(conn, :update_status, status: status)
      {:error, :disabled} -> {:error, :update_check_off}
      {:error, _reason} -> {:error, :github_unreachable}
    end
  end

  def check_update(%Conn{}, _params), do: {:error, :forbidden}
end
