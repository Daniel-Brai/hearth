defmodule HearthWeb.CommunityRoleController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.IAM
  alias Plug.Conn

  tags ["Communities"]

  operation :index,
    summary: "List a community's roles",
    parameters: [community_id: [in: :path, schema: %{type: :string, format: :uuid}]],
    responses: [
      ok: {%{type: :array, items: Schema.Role}, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[required|uuid]}

  def index(%Conn{assigns: %{auth: auth}} = conn, %{"community_id" => community_id}) do
    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         true <- Communities.readable?(community, auth) do
      render(conn, :index, roles: IAM.list_roles(community.id))
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  operation :create,
    summary: "Add a role to a community",
    description: "Needs role.update",
    security: [%{"bearer" => []}],
    parameters: [community_id: [in: :path, schema: %{type: :string, format: :uuid}]],
    request_body: Schema.CreateRoleBody,
    responses: [
      created: {Schema.Role, description: "Created"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "key" => ~V[required|string|max:30],
    "name" => ~V[required|string|max:30],
    "color" => ~V[string],
    "position" => ~V[integer|min:0],
    "permissions" => ~V[list],
    "permissions.*" => ~V[string]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => community_id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    attrs =
      params |> Map.take(~w[key name color position permissions]) |> Common.atomize_string_keys()

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, role} <- Communities.create_role(auth, community, attrs) do
      conn
      |> put_status(:created)
      |> render(:show, role: role)
    end
  end

  operation :update,
    summary: "Change a role",
    description: "Needs role.update and the Owner role can't be changed",
    security: [%{"bearer" => []}],
    parameters: [id: [in: :path, schema: %{type: :string, format: :uuid}]],
    request_body: Schema.UpdateRoleBody,
    responses: [
      ok: {Schema.Role, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "name" => ~V[string|max:30],
    "color" => ~V[string],
    "position" => ~V[integer|min:0],
    "permissions" => ~V[list],
    "permissions.*" => ~V[string]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    changes =
      params |> Map.take(~w[name color position permissions]) |> Common.atomize_string_keys()

    with {:ok, role} <- Communities.get_role(id),
         {:ok, role} <- Communities.update_role(auth, role, changes) do
      render(conn, :show, role: role)
    end
  end

  operation :delete,
    summary: "Delete a role",
    description: "The Owner role and the default role can't be deleted",
    security: [%{"bearer" => []}],
    parameters: [id: [in: :path, schema: %{type: :string, format: :uuid}]],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def delete(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, role} <- Communities.get_role(id),
         {:ok, _role} <- Communities.delete_role(auth, role) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :member_roles,
    summary: "Set the roles a member holds",
    description: "Replaces their roles and never makes or unmakes the Owner",
    security: [%{"bearer" => []}],
    parameters: [
      community_id: [in: :path, schema: %{type: :string, format: :uuid}],
      user_id: [in: :path, schema: %{type: :string, format: :uuid}]
    ],
    request_body: Schema.MemberRolesBody,
    responses: [
      ok: {Schema.MemberRoles, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "user_id" => ~V[required|uuid],
    "keys" => ~V[present|list],
    "keys.*" => ~V[string]
  }

  def member_roles(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id, "user_id" => user_id, "keys" => keys} = params

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, member} <- Accounts.get_user(id: user_id),
         {:ok, membership} <- Communities.set_member_roles(auth, community, member, keys) do
      render(conn, :member_roles,
        user_id: member.id,
        keys: Enum.map(membership.roles, & &1.key)
      )
    end
  end
end
