defmodule HearthWeb.RecordingController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Communities
  alias Hearth.Events
  alias Hearth.Forum
  alias Hearth.Voice
  alias HearthWeb.Paging
  alias Plug.Conn

  tags ["Voice"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  @list_responses [
    ok: {Schema.VoiceRecordingList, description: "OK"},
    forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
    not_found: %Reference{"$ref": "#/components/responses/not_found"},
    unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
    unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
  ]

  operation :room_index,
    summary: "List a room's recordings",
    description: "For members of the room's community, newest first, a page at a time",
    security: [%{"bearer" => []}],
    parameters: [{:id, @id} | Schema.paging()],
    responses: [
      ok: {Schema.VoiceRecordingPage, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def room_index(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id}) do
    with {:ok, room} <- Communities.get_room(id: id),
         {:ok, page} <- Voice.list_room_recordings(auth, room, Paging.opts(conn)) do
      render(conn, :page, page: page)
    end
  end

  operation :event_index,
    summary: "List an event's recordings",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: @list_responses

  @validate %{"id" => ~V[required|uuid]}

  def event_index(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id}) do
    with {:ok, event} <- Events.get_event(id: id) do
      list(conn, auth, {:event_id, event.id, event.community_id})
    end
  end

  operation :post_index,
    summary: "List a post's recordings",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: @list_responses

  @validate %{"id" => ~V[required|uuid]}

  def post_index(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id}) do
    with {:ok, post} <- Forum.get_post(id: id),
         true <- Forum.visible?(auth, post) do
      list(conn, auth, {:post_id, post.id, post.community_id})
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  operation :show,
    summary: "Show a recording",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      ok: {Schema.VoiceRecording, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def show(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id}) do
    with {:ok, recording} <- Voice.get_recording(auth, id) do
      render(conn, :show, recording: recording)
    end
  end

  operation :update,
    summary: "Rename a recording",
    description: "For the person who started it",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.RenameRecordingBody,
    responses: [
      ok: {Schema.VoiceRecording, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid], "title" => ~V[required|string|min:1|max:200]}

  def update(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id, "title" => title}) do
    with {:ok, recording} <- Voice.rename_recording(auth, id, title) do
      render(conn, :show, recording: recording)
    end
  end

  operation :delete,
    summary: "Delete a recording",
    description:
      "For the person who started it, once it has stopped. Its transcript goes with it",
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

  def delete(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id}) do
    with {:ok, _recording} <- Voice.delete_recording(auth, id) do
      send_resp(conn, :no_content, "")
    end
  end

  defp list(conn, auth, scope) do
    with {:ok, recordings} <- Voice.list_recordings(auth, scope) do
      render(conn, :index, recordings: recordings)
    end
  end
end
