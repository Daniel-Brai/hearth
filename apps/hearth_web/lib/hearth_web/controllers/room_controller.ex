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
    "group_id" => ~V[uuid],
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
      |> Map.take(~w[name type topic group_id position access role_ids])
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
    "group_id" => ~V[uuid],
    "position" => ~V[integer|min:0],
    "access" => ~V[allowed:everyone,roles],
    "role_ids" => ~V[list],
    "role_ids.*" => ~V[uuid],
    "settings" => ~V[map],
    "settings.link_previews" => ~V[boolean],
    "settings.sounds_enabled" => ~V[boolean],
    "settings.sounds_mode" => ~V[allowed:everyone,roles,people],
    "settings.sounds_role_ids" => ~V[list|max:50],
    "settings.sounds_role_ids.*" => ~V[uuid],
    "settings.sounds_user_ids" => ~V[list|max:200],
    "settings.sounds_user_ids.*" => ~V[uuid]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    changes =
      params
      |> Map.take(~w[name topic group_id position access role_ids settings])
      |> Common.atomize_string_keys()

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

  operation :create_group,
    summary: "Add a room group to a community",
    description: "Needs room.update. It goes last",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    request_body: Schema.RoomGroupBody,
    responses: [
      created: {Schema.RoomGroup, description: "Created"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[required|uuid], "name" => ~V[required|string|min:1|max:40]}

  def create_group(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id, "name" => name} = params

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, group} <- Communities.create_room_group(auth, community, %{name: name}) do
      conn |> put_status(:created) |> render(:create_group, group: group)
    end
  end

  operation :update_group,
    summary: "Rename a room group",
    description: "Needs room.update",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.RoomGroupBody,
    responses: [
      ok: {Schema.RoomGroup, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid], "name" => ~V[required|string|min:1|max:40]}

  def update_group(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "name" => name}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, group} <- Communities.get_room_group(id),
         {:ok, group} <- Communities.rename_room_group(auth, group, %{name: name}) do
      render(conn, :update_group, group: group)
    end
  end

  operation :delete_group,
    summary: "Delete a room group",
    description: "Needs room.update. Its rooms move after the rooms in no group",
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

  def delete_group(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, group} <- Communities.get_room_group(id),
         {:ok, _group} <- Communities.delete_room_group(auth, group) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :arrange,
    summary: "Arrange a community's rooms and room groups",
    description: "Needs room.update. Lists every group and every room that isn't archived once",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    request_body: Schema.RoomLayoutBody,
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "groups" => ~V[present|list],
    "groups.*.id" => ~V[required|uuid],
    "groups.*.room_ids" => ~V[present|list],
    "groups.*.room_ids.*" => ~V[uuid],
    "room_ids" => ~V[present|list],
    "room_ids.*" => ~V[uuid]
  }

  def arrange(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id, "groups" => groups, "room_ids" => room_ids} = params

    layout = %{
      groups: Enum.map(groups, &%{id: &1["id"], room_ids: &1["room_ids"]}),
      room_ids: room_ids
    }

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         :ok <- Communities.arrange_rooms(auth, community, layout) do
      send_resp(conn, :no_content, "")
    end
  end
end
