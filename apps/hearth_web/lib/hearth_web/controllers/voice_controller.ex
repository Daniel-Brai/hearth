defmodule HearthWeb.VoiceController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Voice
  alias Plug.Conn

  tags ["Voice"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  @action_errors [
    bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
    forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
    not_found: %Reference{"$ref": "#/components/responses/not_found"},
    unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
  ]

  @done [{:no_content, %Reference{"$ref": "#/components/responses/no_content"}} | @action_errors]

  @unprocessable [
    unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
  ]

  operation :current,
    summary: "Show a room's live voice session",
    description: "Not found when the room isn't live",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      ok: {Schema.VoiceSession, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def current(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, room} <- find_room(id, auth),
         {:ok, session} <- Voice.get_session(room_id: room.id, ended_at: nil) do
      render(conn, :session, session: session, recording: Voice.recording?(session))
    end
  end

  operation :index,
    summary: "List live sessions in my communities",
    description: "So the sidebar can show which voice rooms are on air without opening them",
    security: [%{"bearer" => []}],
    responses: [
      ok: {%{type: :array, items: Schema.VoiceSession}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def index(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    sessions = Voice.live_for(auth)

    render(conn, :index,
      sessions: sessions,
      recording: Map.new(sessions, &{&1.id, Voice.recording?(&1)}),
      people: Map.new(sessions, &{&1.id, Voice.people_in(&1)})
    )
  end

  operation :create,
    summary: "Start a voice session",
    description: "Needs voice-session.create and returns the live session if the room has one",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.StartVoiceSessionBody,
    responses: [
      created: {Schema.VoiceSession, description: "Created"},
      ok: {Schema.VoiceSession, description: "Already live"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "mode" => ~V[allowed:stage,open],
    "topic" => ~V[string|max:200]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    attrs = params |> Map.take(~w[mode topic]) |> Common.atomize_string_keys()

    with {:ok, room} <- find_room(id, auth),
         do: started(conn, Voice.start_session(auth, room, attrs))
  end

  operation :discuss,
    summary: "Start a live discussion of a post",
    description: "Needs voice-session.create and the post's author",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      created: {Schema.VoiceSession, description: "Created"},
      ok: {Schema.VoiceSession, description: "Already live"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def discuss(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, post} <- Forum.get_post(id: id), do: started(conn, Voice.discuss_live(auth, post))
  end

  operation :show,
    summary: "Show a live voice session's state",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [{:ok, {Schema.VoiceState, description: "OK"}} | @action_errors] ++ @unprocessable

  @validate %{"id" => ~V[required|uuid]}

  def show(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, session} <- find_session(id, auth),
         {:ok, snapshot} <- Voice.snapshot(auth, session) do
      render(conn, :state,
        session: session,
        snapshot: snapshot,
        host_tools: Voice.host_tools?(auth, session),
        may_record: Voice.may_record?(auth, session)
      )
    end
  end

  operation :end_session,
    summary: "End a voice session",
    description: "Needs the host or content.remove",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid]}

  def end_session(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.end_session(auth, &1))
  end

  operation :hand,
    summary: "Raise or lower your hand",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.HandBody,
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid], "raised" => ~V[required|boolean]}

  def hand(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "raised" => raised}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.raise_hand(auth, &1, raised))
  end

  operation :mute,
    summary: "Show your mute to the room",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.MuteBody,
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid], "muted" => ~V[required|boolean]}

  def mute(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "muted" => muted}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.self_mute(auth, &1, muted))
  end

  operation :invite,
    summary: "Invite a listener on stage",
    description: "Needs the host or content.remove",
    security: [%{"bearer" => []}],
    parameters: [id: @id, user_id: @id],
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid], "user_id" => ~V[required|uuid]}

  def invite(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "user_id" => user_id}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.invite(auth, &1, user_id))
  end

  operation :demote,
    summary: "Move a speaker back to listeners",
    description: "Needs the host or content.remove unless stepping down yourself",
    security: [%{"bearer" => []}],
    parameters: [id: @id, user_id: @id],
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid], "user_id" => ~V[required|uuid]}

  def demote(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "user_id" => user_id}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.demote(auth, &1, user_id))
  end

  operation :server_mute,
    summary: "Server mute someone or lift it",
    description: "Needs the host or content.remove",
    security: [%{"bearer" => []}],
    parameters: [id: @id, user_id: @id],
    request_body: Schema.MuteBody,
    responses: @done ++ @unprocessable

  @validate %{
    "id" => ~V[required|uuid],
    "user_id" => ~V[required|uuid],
    "muted" => ~V[required|boolean]
  }

  def server_mute(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "user_id" => user_id, "muted" => muted} = params

    act(conn, id, &Voice.server_mute(auth, &1, user_id, muted))
  end

  operation :disconnect,
    summary: "Disconnect someone",
    description: "Needs the host or content.remove",
    security: [%{"bearer" => []}],
    parameters: [id: @id, user_id: @id],
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid], "user_id" => ~V[required|uuid]}

  def disconnect(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "user_id" => user_id}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.disconnect(auth, &1, user_id))
  end

  operation :start_share,
    summary: "Start the screen share",
    description: "Only one person shares at a time",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid]}

  def start_share(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.start_share(auth, &1))
  end

  operation :stop_share,
    summary: "Stop the screen share",
    description: "Needs the sharer, the host or content.remove",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid]}

  def stop_share(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.stop_share(auth, &1))
  end

  operation :start_recording,
    summary: "Start recording a session",
    description: "Needs the host or voice-recording.create",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid]}

  def start_recording(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.start_recording(auth, &1))
  end

  operation :stop_recording,
    summary: "Stop recording a session",
    description: "Needs the host or voice-recording.create",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: @done ++ @unprocessable

  @validate %{"id" => ~V[required|uuid]}

  def stop_recording(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    act(conn, id, &Voice.stop_recording(auth, &1))
  end

  defp act(%Conn{assigns: %{auth: auth}} = conn, id, fun) do
    with {:ok, session} <- find_session(id, auth),
         :ok <- fun.(session) do
      send_resp(conn, :no_content, "")
    end
  end

  defp find_room(id, auth) do
    with {:ok, room} <- Communities.get_room(id: id),
         true <- Communities.room_visible?(auth, room) do
      {:ok, room}
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  defp find_session(id, auth) do
    with {:ok, session} <- Voice.get_session(id: id),
         {:ok, _room} <- Communities.view_room(auth, id: session.room_id) do
      {:ok, session}
    end
  end

  defp started(conn, {:ok, session}),
    do: conn |> put_status(:created) |> render(:session, session: session)

  defp started(conn, {:error, :already_live, session}),
    do: render(conn, :session, session: session)

  defp started(_conn, {:error, _reason} = error), do: error
end
