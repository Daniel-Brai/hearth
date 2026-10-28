defmodule HearthWeb.ConversationController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Chat
  alias HearthWeb.Authors
  alias HearthWeb.ConversationJSON
  alias Plug.Conn

  tags ["Chat"]

  operation :index,
    summary: "List my conversations",
    description: "Most recently active first",
    security: [%{"bearer" => []}],
    responses: [
      ok: {%{type: :array, items: Schema.Conversation}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def index(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    conversations = Chat.list_conversations(auth)
    ids = Enum.flat_map(conversations, &ConversationJSON.member_ids/1)

    render(conn, :index, conversations: conversations, people: Authors.people(ids))
  end

  operation :create,
    summary: "Start a direct or group conversation",
    description: "One person starts a direct conversation and more start a group",
    security: [%{"bearer" => []}],
    request_body: Schema.StartConversationBody,
    responses: [
      created: {Schema.Conversation, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "user_ids" => ~V[required|list|min:1|max:20],
    "user_ids.*" => ~V[uuid],
    "name" => ~V[string|min:1|max:60]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"user_ids" => user_ids} = params
    name = params["name"]

    with {:ok, others} <- find_people(user_ids),
         {:ok, conversation} <- start(auth, others, name),
         {:ok, conversation} <- Chat.get_conversation(auth, conversation.id) do
      people = conversation |> ConversationJSON.member_ids() |> Authors.people()

      conn
      |> put_status(:created)
      |> render(:create, conversation: conversation, people: people)
    end
  end

  defp start(auth, [other], _name), do: Chat.start_direct(auth, other)
  defp start(auth, others, name), do: Chat.start_group(auth, others, name)

  defp find_people(ids) do
    people = Accounts.list_users(ids)

    case length(people) == length(Enum.uniq(ids)) do
      true -> {:ok, people}
      false -> {:error, :not_found}
    end
  end
end
