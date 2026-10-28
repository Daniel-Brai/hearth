defmodule HearthWeb.BanController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Moderation
  alias HearthWeb.Authors
  alias Plug.Conn

  tags ["Moderation"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :index,
    summary: "List the bans in force in a community",
    description: "Needs member.ban in the community",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    responses: [
      ok: {%{type: :array, items: Schema.Ban}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[required|uuid]}

  def index(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => community_id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, bans} <- Moderation.list_bans(auth, community) do
      ids = Enum.flat_map(bans, &[&1.user_id, &1.banned_by_id])
      render(conn, :index, bans: bans, people: Authors.people(ids))
    end
  end

  operation :create,
    summary: "Ban someone from a community by username",
    description: "Needs member.ban and the reason shows in the public log",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    request_body: Schema.CreateBanBody,
    responses: [
      created: {Schema.Ban, description: "Created"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "username" => ~V[required|string|min:1],
    "reason" => ~V[required|string|min:1|max:500],
    "expires_at" => ~V[string]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id, "username" => username} = params

    changes = params |> Map.take(~w[reason expires_at]) |> Common.atomize_string_keys()

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, ban} <- Moderation.ban_username(auth, community, username, changes) do
      conn
      |> put_status(:created)
      |> render(:show, ban: ban, people: Authors.people([ban.user_id, ban.banned_by_id]))
    end
  end

  operation :lift,
    summary: "Lift a ban early",
    description: "Needs member.ban in the community",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.ReasonBody,
    responses: [
      ok: {Schema.Ban, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "reason" => ~V[string|max:500]
  }

  def lift(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, ban} <- Communities.get_ban(id),
         {:ok, ban} <- Moderation.lift_ban(auth, ban, params["reason"]) do
      render(conn, :show, ban: ban, people: Authors.people([ban.user_id, ban.banned_by_id]))
    end
  end
end
