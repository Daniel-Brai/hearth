defmodule HearthWeb.PollController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Chat
  alias Hearth.Common
  alias Hearth.Communities
  alias HearthWeb.Attachments
  alias HearthWeb.Authors
  alias Plug.Conn

  tags ["Chat"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :create,
    summary: "Start a poll in a room",
    description:
      "Anyone who can send messages there can ask. It arrives as a message whose body is the question",
    security: [%{"bearer" => []}],
    parameters: [room_id: @id],
    request_body: Schema.StartPollBody,
    responses: [
      created: {Schema.ChatMessage, description: "Started"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "room_id" => ~V[required|uuid],
    "question" => ~V[required|string|max:300],
    "options" => ~V[required|list],
    "options.*" => ~V[string|max:100],
    "multiple" => ~V[boolean],
    "closes_at" => ~V[string]
  }

  rate_limit :create, limit: 10, scale: :timer.minutes(1), by: :user

  def create(%Conn{assigns: %{auth: %{}}} = conn, %{"room_id" => room_id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, room} <- Communities.view_room(auth, id: room_id, archived_at: nil),
         {:ok, closes_at} <- closes_at(params["closes_at"]),
         {:ok, message} <- Chat.start_poll(auth, room, attrs(params, closes_at)) do
      conn
      |> put_status(:created)
      |> render(:create,
        message: message,
        authors: Authors.load(message),
        attachments: Attachments.load(message, :message),
        polls: Chat.list_polls(auth, [message])
      )
    end
  end

  operation :show,
    summary: "Show a poll",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      ok: {Schema.Poll, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def show(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, poll} <- Chat.get_poll(auth, id) do
      render(conn, :show, view: Chat.poll_view(auth, poll))
    end
  end

  operation :vote,
    summary: "Vote in a poll, or change my vote",
    description: "Members only, until it closes. No choices takes the vote back",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.VoteBody,
    responses: [
      ok: {Schema.Poll, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "option_ids" => ~V[required|list],
    "option_ids.*" => ~V[uuid]
  }

  rate_limit :vote, limit: 30, scale: :timer.seconds(30), by: :user

  def vote(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "option_ids" => option_ids}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, poll} <- Chat.get_poll(auth, id),
         {:ok, view} <- Chat.vote(auth, poll, option_ids) do
      render(conn, :show, view: view)
    end
  end

  operation :update,
    summary: "Close a poll",
    description: "Its starter or anyone with content.remove",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.UpdatePollBody,
    responses: [
      ok: {Schema.Poll, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid], "closed" => ~V[required|boolean]}

  def update(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, poll} <- Chat.get_poll(auth, id),
         {:ok, closed} <- Chat.close_poll(auth, poll) do
      render(conn, :show, view: Chat.poll_view(auth, closed))
    end
  end

  defp attrs(params, closes_at) do
    params
    |> Map.take(~w[question options multiple])
    |> Common.atomize_string_keys()
    |> Map.put(:closes_at, closes_at)
  end

  defp closes_at(nil), do: {:ok, nil}
  defp closes_at(at), do: Common.parse_datetime(at)
end
