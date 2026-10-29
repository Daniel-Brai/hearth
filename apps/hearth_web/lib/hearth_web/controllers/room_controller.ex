defmodule HearthWeb.RoomController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Plug.Conn

  tags ["Communities"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :archived,
    summary: "List a community's archived rooms",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    responses: [
      ok: {%{type: :array, items: Schema.Room}, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[required|uuid]}

  def archived(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => community_id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, rooms} <- Communities.list_archived_rooms(auth, community) do
      render(conn, :archived, rooms: rooms)
    end
  end

  operation :create,
    summary: "Add a room to a community",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    request_body: Schema.CreateRoomBody,
    responses: [
      created: {Schema.Room, description: "Created"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "name" => ~V[required|string|min:1|max:40],
    "type" => ~V[allowed:text,voice],
    "topic" => ~V[string|max:200],
    "position" => ~V[integer|min:0],
    "access" => ~V[allowed:everyone,roles],
    "role_ids" => ~V[list],
    "role_ids.*" => ~V[uuid]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id} = params

    changes =
      params
      |> Map.take(~w[name type topic position access role_ids])
      |> Common.atomize_string_keys()

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, room} <- Communities.create_room(auth, community, changes) do
      conn |> put_status(:created) |> render(:create, room: room)
    end
  end

  operation :update,
    summary: "Change a room",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.UpdateRoomBody,
    responses: [
      ok: {Schema.Room, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "name" => ~V[string|min:1|max:40],
    "topic" => ~V[string|max:200],
    "position" => ~V[integer|min:0],
    "access" => ~V[allowed:everyone,roles],
    "role_ids" => ~V[list],
    "role_ids.*" => ~V[uuid]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    changes =
      params |> Map.take(~w[name topic position access role_ids]) |> Common.atomize_string_keys()

    with {:ok, room} <- Communities.view_room(auth, id: id, archived_at: nil),
         {:ok, room} <- Communities.update_room(auth, room, changes) do
      render(conn, :update, room: room)
    end
  end

  operation :archive,
    summary: "Archive a room",
    description: "Its messages stay and it can be restored",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      ok: {Schema.Room, description: "Archived"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def archive(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, room} <- Communities.view_room(auth, id: id, archived_at: nil),
         {:ok, room} <- Communities.archive_room(auth, room) do
      render(conn, :archive, room: room)
    end
  end

  operation :restore,
    summary: "Restore an archived room",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      ok: {Schema.Room, description: "Restored"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def restore(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, room} <- Communities.view_room(auth, id: id),
         {:ok, room} <- Communities.restore_room(auth, room) do
      render(conn, :restore, room: room)
    end
  end

  operation :delete,
    summary: "Delete a room for good",
    description: "Its messages and events go with it",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def delete(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, room} <- Communities.view_room(auth, id: id),
         {:ok, _room} <- Communities.delete_room(auth, room) do
      send_resp(conn, :no_content, "")
    end
  end
end
