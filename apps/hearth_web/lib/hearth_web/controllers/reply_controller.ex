defmodule HearthWeb.ReplyController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias HearthWeb.Attachments
  alias HearthWeb.Authors
  alias HearthWeb.Paging
  alias Plug.Conn

  tags ["Forum"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :index,
    summary: "List one level of a post's replies",
    description: "The top level, or the direct replies to parent_id, which read oldest first",
    parameters:
      [
        post_id: @id,
        parent_id: [in: :query, schema: %{type: :string, format: :uuid}],
        sort: [in: :query, schema: %{type: :string, enum: ~w[helpful newest]}]
      ] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.Reply), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "post_id" => ~V[required|uuid],
    "parent_id" => ~V[uuid],
    "sort" => ~V[allowed:helpful,newest],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def index(%Conn{assigns: %{auth: auth}} = conn, %{"post_id" => post_id} = params) do
    sort = Common.to_atom(params["sort"] || "helpful")

    with {:ok, post} <- find_post(post_id, auth),
         {:ok, parent} <- find_parent(post, params["parent_id"]),
         opts = [viewer: auth, parent: parent, sort: sort] ++ Paging.opts(conn),
         %{data: replies} = page <- Forum.list_replies(post, opts) do
      render(conn, :index,
        page: page,
        authors: Authors.load(replies),
        attachments: Attachments.load(replies, :reply)
      )
    end
  end

  operation :create,
    summary: "Reply to a post or to another reply",
    security: [%{"bearer" => []}],
    parameters: [post_id: @id],
    request_body: Schema.CreateReplyBody,
    responses: [
      created: {Schema.Reply, description: "Created"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "post_id" => ~V[required|uuid],
    "body" => ~V[string|max:10000],
    "attachment_ids" => ~V[list],
    "attachment_ids.*" => ~V[uuid],
    "parent_reply_id" => ~V[uuid]
  }

  rate_limit :create, limit: 60, scale: :timer.minutes(10), by: :user

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"post_id" => post_id} = params

    attrs =
      params |> Map.take(~w[body attachment_ids parent_reply_id]) |> Common.atomize_string_keys()

    with {:ok, post} <- find_post(post_id, auth),
         {:ok, reply} <- Forum.reply(auth, post, attrs) do
      conn
      |> put_status(:created)
      |> render(:create,
        reply: reply,
        authors: Authors.load(reply),
        attachments: Attachments.load(reply, :reply)
      )
    end
  end

  operation :update,
    summary: "Edit a reply",
    description: "Only its author can",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.EditBody,
    responses: [
      ok: {Schema.Reply, description: "OK"},
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

    with {:ok, reply} <- find_reply(id, auth),
         {:ok, reply} <- Forum.update_reply(auth, reply, changes) do
      render(conn, :update,
        reply: reply,
        authors: Authors.load(reply),
        attachments: Attachments.load(reply, :reply)
      )
    end
  end

  operation :delete,
    summary: "Delete a reply",
    description: "Only its author can, and one with answers stays as Reply deleted",
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

    with {:ok, reply} <- find_reply(id, auth),
         {:ok, _reply} <- Forum.delete_reply(auth, reply) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :helpful,
    summary: "Mark a reply as helpful, or take the mark back",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      ok: {Schema.Toggle, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def helpful(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, reply} <- find_reply(id, auth),
         {:ok, state} <- Forum.toggle_helpful(auth, reply) do
      render(conn, :helpful, on: state == :marked)
    end
  end

  defp find_post(id, auth) do
    with {:ok, post} <- Forum.get_post(id: id, status: :published),
         {:ok, community} <- Communities.get_community(id: post.community_id, archived_at: nil),
         true <- Communities.readable?(community, auth) do
      {:ok, post}
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  defp find_parent(_post, nil), do: {:ok, nil}

  defp find_parent(post, id) do
    case Forum.get_reply(id) do
      {:ok, %{post_id: post_id} = reply} when post_id == post.id -> {:ok, reply}
      _other -> {:error, :not_found}
    end
  end

  defp find_reply(id, auth) do
    with {:ok, reply} <- Forum.get_reply(id),
         {:ok, _post} <- find_post(reply.post_id, auth) do
      {:ok, reply}
    end
  end
end
