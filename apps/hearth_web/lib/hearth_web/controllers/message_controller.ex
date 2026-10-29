defmodule HearthWeb.MessageController do
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
  alias HearthWeb.Paging
  alias Plug.Conn

  tags ["Chat"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]
  @parent [
    in: :query,
    schema: %{type: :string, format: :uuid},
    description: "The message whose answers to list, or the main timeline without it"
  ]

  operation :room_index,
    summary: "List a room's messages",
    description: "Newest first",
    security: [%{"bearer" => []}],
    parameters: [room_id: @id, parent_id: @parent] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.ChatMessage), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "room_id" => ~V[required|uuid],
    "parent_id" => ~V[uuid],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def room_index(%Conn{assigns: %{auth: %{}}} = conn, %{"room_id" => room_id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, room} <- Communities.view_room(auth, id: room_id, archived_at: nil) do
      list(conn, params, auth, room)
    end
  end

  operation :room_create,
    summary: "Send a message to a room",
    security: [%{"bearer" => []}],
    parameters: [room_id: @id],
    request_body: Schema.SendMessageBody,
    responses: [
      created: {Schema.ChatMessage, description: "Sent"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "room_id" => ~V[required|uuid],
    "body" => ~V[string|max:4000],
    "attachment_ids" => ~V[list],
    "attachment_ids.*" => ~V[uuid],
    "reply_to_id" => ~V[uuid],
    "kind" => ~V[allowed:text,action,sound]
  }

  rate_limit :room_create, limit: 30, scale: :timer.seconds(30), by: :user

  def room_create(%Conn{assigns: %{auth: %{}}} = conn, %{"room_id" => room_id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, room} <- Communities.view_room(auth, id: room_id, archived_at: nil) do
      send_message(conn, params, auth, room)
    end
  end

  operation :conversation_index,
    summary: "List a conversation's messages",
    description: "Newest first",
    security: [%{"bearer" => []}],
    parameters: [conversation_id: @id, parent_id: @parent] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.ChatMessage), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "conversation_id" => ~V[required|uuid],
    "parent_id" => ~V[uuid],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def conversation_index(%Conn{assigns: %{auth: %{}}} = conn, %{"conversation_id" => id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, conversation} <- Chat.get_conversation(auth, id) do
      list(conn, params, auth, conversation)
    end
  end

  operation :conversation_create,
    summary: "Send a message to a conversation",
    security: [%{"bearer" => []}],
    parameters: [conversation_id: @id],
    request_body: Schema.SendMessageBody,
    responses: [
      created: {Schema.ChatMessage, description: "Sent"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "conversation_id" => ~V[required|uuid],
    "body" => ~V[string|max:4000],
    "attachment_ids" => ~V[list],
    "attachment_ids.*" => ~V[uuid],
    "reply_to_id" => ~V[uuid],
    "kind" => ~V[allowed:text,action,sound]
  }

  rate_limit :conversation_create, limit: 30, scale: :timer.seconds(30), by: :user

  def conversation_create(
        %Conn{assigns: %{auth: %{}}} = conn,
        %{"conversation_id" => id} = params
      ) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, conversation} <- Chat.get_conversation(auth, id) do
      send_message(conn, params, auth, conversation)
    end
  end

  operation :update,
    summary: "Edit a message",
    description: "Only its author can",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.EditBody,
    responses: [
      ok: {Schema.ChatMessage, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "body" => ~V[string|max:10000],
    "attachment_ids" => ~V[list],
    "attachment_ids.*" => ~V[uuid]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    changes = params |> Map.take(~w[body attachment_ids]) |> Common.atomize_string_keys()

    with {:ok, message} <- Chat.get_message(id),
         {:ok, message} <- Chat.edit_message(auth, message, changes) do
      render(conn, :update,
        message: message,
        authors: Authors.load(message),
        attachments: Attachments.load(message, :message),
        reactions: Chat.list_reactions(auth, [message]),
        mentions_all: Chat.mentions_all([message])
      )
    end
  end

  operation :delete,
    summary: "Delete a message",
    description: "One with answers stays as Message deleted",
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

    with {:ok, message} <- Chat.get_message(id),
         {:ok, _message} <- Chat.delete_message(auth, message) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :react,
    summary: "Add a reaction to a message, or take it back",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.ReactionBody,
    responses: [
      ok: {Schema.Toggle, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "emoji" => ~V[required|string|max:32]
  }

  def react(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "emoji" => emoji} = params

    with {:ok, message} <- Chat.get_message(id),
         {:ok, state} <- Chat.toggle_reaction(auth, message, emoji) do
      render(conn, :react, on: state == :added)
    end
  end

  operation :preview,
    summary: "Take a message's link card off, or put it back",
    description: "Its author can, and in a room so can anyone with content.remove",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.PreviewBody,
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid], "hidden" => ~V[required|boolean]}

  def preview(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "hidden" => hidden}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, message} <- Chat.get_message(id),
         {:ok, _message} <- Chat.hide_preview(auth, message, hidden) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :read,
    summary: "Mark a conversation or room as read up to a message",
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

  def read(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, message} <- Chat.get_message(id),
         :ok <- Chat.mark_read(auth, message) do
      send_resp(conn, :no_content, "")
    end
  end

  defp list(conn, params, auth, place) do
    with {:ok, parent} <- find_parent(params["parent_id"]),
         %{data: messages} = page <-
           Chat.list_messages(auth, place, [parent: parent] ++ Paging.opts(conn)) do
      render(conn, :index,
        page: page,
        authors: Authors.load(messages),
        attachments: Attachments.load(messages, :message),
        reactions: Chat.list_reactions(auth, messages),
        mentions_all: Chat.mentions_all(messages)
      )
    end
  end

  defp send_message(conn, params, auth, place) do
    kind = Common.to_atom(params["kind"] || "text")

    attrs =
      params
      |> Map.take(~w[body attachment_ids reply_to_id])
      |> Common.atomize_string_keys()
      |> Map.put(:kind, kind)

    with {:ok, message} <- Chat.send_message(auth, place, attrs) do
      conn
      |> put_status(:created)
      |> render(:create,
        message: message,
        authors: Authors.load(message),
        attachments: Attachments.load(message, :message),
        mentions_all: Chat.mentions_all([message])
      )
    end
  end

  defp find_parent(nil), do: {:ok, nil}
  defp find_parent(id), do: Chat.get_message(id)
end
