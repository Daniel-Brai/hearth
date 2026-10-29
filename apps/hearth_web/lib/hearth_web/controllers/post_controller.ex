defmodule HearthWeb.PostController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Transcripts
  alias Hearth.Voice
  alias HearthWeb.Attachments
  alias HearthWeb.Authors
  alias HearthWeb.Paging
  alias HearthWeb.Reports
  alias Plug.Conn

  tags ["Forum"]

  @id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :index,
    summary: "List a community's posts",
    description: "Newest activity first, without pinned posts",
    parameters:
      [
        community_id: @id,
        kind_id: [
          in: :query,
          schema: %{type: :string, format: :uuid},
          description: "Only this kind"
        ]
      ] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.Post), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "kind_id" => ~V[uuid],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def index(%Conn{assigns: %{auth: auth}} = conn, %{"community_id" => community_id} = params) do
    filters = for kind_id <- [params["kind_id"]], kind_id != nil, do: {:kind_id, kind_id}

    with {:ok, community} <- find_community(community_id, auth),
         %{data: posts} = page <- Forum.list_posts(community, filters ++ Paging.opts(conn)) do
      render(conn, :index,
        page: page,
        authors: Authors.load(posts),
        attachments: Attachments.load(posts, :post),
        reported: Reports.load(posts, auth, :post),
        in_review: Reports.in_review(posts, :post),
        watching: Forum.watched(auth, posts),
        reactions: Forum.list_reactions(auth, posts),
        seen: Forum.seen(auth, posts)
      )
    end
  end

  operation :pinned,
    summary: "List a community's pinned posts",
    parameters: [community_id: @id],
    responses: [
      ok: {%{type: :array, items: Schema.Post}, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[required|uuid]}

  def pinned(%Conn{assigns: %{auth: auth}} = conn, %{"community_id" => community_id}) do
    with {:ok, community} <- find_community(community_id, auth) do
      posts = Forum.list_pinned(community)

      render(conn, :pinned,
        posts: posts,
        authors: Authors.load(posts),
        attachments: Attachments.load(posts, :post),
        reported: Reports.load(posts, auth, :post),
        in_review: Reports.in_review(posts, :post),
        watching: Forum.watched(auth, posts),
        reactions: Forum.list_reactions(auth, posts),
        seen: Forum.seen(auth, posts)
      )
    end
  end

  operation :create,
    summary: "Write a post",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    request_body: Schema.CreatePostBody,
    responses: [
      created: {Schema.Post, description: "Created"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "kind_id" => ~V[required|uuid],
    "title" => ~V[required|string|max:150],
    "body" => ~V[string|max:40000],
    "attachment_ids" => ~V[list],
    "attachment_ids.*" => ~V[uuid]
  }

  rate_limit :create, limit: 20, scale: :timer.minutes(10), by: :user

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id} = params

    attrs =
      params |> Map.take(~w[kind_id title body attachment_ids]) |> Common.atomize_string_keys()

    with {:ok, community} <- find_community(community_id, auth),
         {:ok, post} <- Forum.create_post(auth, community, attrs) do
      conn
      |> put_status(:created)
      |> render(:create,
        post: post,
        authors: Authors.load(post),
        attachments: Attachments.load(post, :post),
        reported: Reports.load(post, auth, :post),
        in_review: Reports.in_review(post, :post),
        watching: Forum.watched(auth, post)
      )
    end
  end

  operation :promote,
    summary: "Turn room messages into a post",
    description: "Needs chat.promote and each message keeps its author",
    security: [%{"bearer" => []}],
    parameters: [room_id: [in: :path, schema: %{type: :string, format: :uuid}]],
    request_body: Schema.PromoteBody,
    responses: [
      created: {Schema.Post, description: "Created"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "room_id" => ~V[required|uuid],
    "message_ids" => ~V[required|list|min:1|max:50],
    "message_ids.*" => ~V[uuid],
    "kind_id" => ~V[required|uuid],
    "title" => ~V[required|string|max:150]
  }

  rate_limit :promote, limit: 20, scale: :timer.minutes(10), by: :user

  def promote(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"room_id" => room_id, "message_ids" => message_ids} = params

    attrs = params |> Map.take(~w[kind_id title]) |> Common.atomize_string_keys()

    with {:ok, room} <- Communities.view_room(auth, id: room_id, type: :text),
         {:ok, post} <- Forum.promote(auth, room, message_ids, attrs) do
      conn
      |> put_status(:created)
      |> render(:create,
        post: post,
        authors: Authors.load(post),
        attachments: Attachments.load(post, :post),
        watching: Forum.watched(auth, post)
      )
    end
  end

  operation :show,
    summary: "Show a post",
    parameters: [id: @id],
    responses: [
      ok: {Schema.Post, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def show(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id}) do
    with {:ok, post} <- find_post(id, auth) do
      render(conn, :show,
        post: post,
        authors: Authors.load(post),
        attachments: Attachments.load(post, :post),
        reported: Reports.load(post, auth, :post),
        in_review: Reports.in_review(post, :post),
        watching: Forum.watched(auth, post),
        live: Voice.live_on_posts([post.id]),
        reactions: Forum.list_reactions(auth, [post]),
        seen: Forum.seen(auth, [post]),
        transcripts: transcripts(auth, post)
      )
    end
  end

  operation :update,
    summary: "Edit a post",
    description: "Only its author can",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.UpdatePostBody,
    responses: [
      ok: {Schema.Post, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "kind_id" => ~V[uuid],
    "title" => ~V[string|min:1|max:150],
    "body" => ~V[string|max:40000],
    "attachment_ids" => ~V[list],
    "attachment_ids.*" => ~V[uuid]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id} = params

    changes =
      params |> Map.take(~w[kind_id title body attachment_ids]) |> Common.atomize_string_keys()

    with {:ok, post} <- find_post(id, auth),
         {:ok, post} <- Forum.update_post(auth, post, changes) do
      render(conn, :update,
        post: post,
        authors: Authors.load(post),
        attachments: Attachments.load(post, :post),
        reported: Reports.load(post, auth, :post),
        in_review: Reports.in_review(post, :post),
        watching: Forum.watched(auth, post)
      )
    end
  end

  operation :delete,
    summary: "Delete a post",
    description: "Only its author can, anyone else removes it through moderation",
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

    with {:ok, post} <- find_post(id, auth),
         {:ok, _post} <- Forum.delete_post(auth, post) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :pin,
    summary: "Pin or unpin a post",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.PinBody,
    responses: [
      ok: {Schema.Post, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "pinned" => ~V[required|boolean]
  }

  def pin(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "pinned" => pinned} = params

    with {:ok, post} <- find_post(id, auth),
         {:ok, post} <- Forum.pin_post(auth, post, pinned) do
      render(conn, :pin,
        post: post,
        authors: Authors.load(post),
        attachments: Attachments.load(post, :post),
        reported: Reports.load(post, auth, :post),
        in_review: Reports.in_review(post, :post),
        watching: Forum.watched(auth, post)
      )
    end
  end

  operation :lock,
    summary: "Lock or unlock a post",
    description: "A locked post takes no replies",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.LockBody,
    responses: [
      ok: {Schema.Post, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "locked" => ~V[required|boolean]
  }

  def lock(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "locked" => locked} = params

    with {:ok, post} <- find_post(id, auth),
         {:ok, post} <- Forum.lock_post(auth, post, locked) do
      render(conn, :lock,
        post: post,
        authors: Authors.load(post),
        attachments: Attachments.load(post, :post),
        reported: Reports.load(post, auth, :post),
        in_review: Reports.in_review(post, :post),
        watching: Forum.watched(auth, post)
      )
    end
  end

  operation :answer,
    summary: "Mark the reply that answers a post",
    description: "Only kinds that take answers have one",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.AnswerBody,
    responses: [
      ok: {Schema.Post, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "reply_id" => ~V[uuid]
  }

  def answer(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id} = params) do
    %Conn{assigns: %{auth: auth}} = conn
    reply_id = params["reply_id"]

    with {:ok, post} <- find_post(id, auth),
         {:ok, reply} <- find_reply(reply_id),
         {:ok, post} <- Forum.mark_answer(auth, post, reply) do
      render(conn, :answer,
        post: post,
        authors: Authors.load(post),
        attachments: Attachments.load(post, :post),
        reported: Reports.load(post, auth, :post),
        in_review: Reports.in_review(post, :post),
        watching: Forum.watched(auth, post)
      )
    end
  end

  operation :helpful,
    summary: "Mark a post as helpful, or take the mark back",
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

    with {:ok, post} <- find_post(id, auth),
         {:ok, state} <- Forum.toggle_helpful(auth, post) do
      render(conn, :helpful, on: state == :marked)
    end
  end

  operation :react,
    summary: "Add a reaction to a post, or take it back",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.ReactionBody,
    responses: [
      ok: {Schema.Toggle, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid], "emoji" => ~V[required|string|max:32]}

  def react(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "emoji" => emoji}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, post} <- find_post(id, auth),
         {:ok, state} <- Forum.toggle_reaction(auth, post, emoji) do
      render(conn, :react, on: state == :added)
    end
  end

  operation :seen,
    summary: "Record that a post has been read",
    description: "Its replies so far stop counting as unread",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def seen(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, post} <- find_post(id, auth),
         :ok <- Forum.mark_seen(auth, post) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :all_seen,
    summary: "Mark every post in my communities as read",
    security: [%{"bearer" => []}],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def all_seen(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    :ok = Forum.mark_all_seen(auth, nil)

    send_resp(conn, :no_content, "")
  end

  operation :community_seen,
    summary: "Mark every post in a community as read",
    security: [%{"bearer" => []}],
    parameters: [community_id: @id],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[required|uuid]}

  def community_seen(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, community} <- Communities.get_community(id: id, archived_at: nil),
         :ok <- Forum.mark_all_seen(auth, community) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :watch,
    summary: "Watch a post, or stop",
    description: "Watchers hear about every reply",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.WatchBody,
    responses: [
      ok: {Schema.Toggle, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "watching" => ~V[required|boolean]
  }

  def watch(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "watching" => watching} = params

    with {:ok, post} <- find_post(id, auth),
         :ok <- Forum.watch_post(auth, post, watching) do
      render(conn, :watch, on: watching)
    end
  end

  defp find_community(id, auth) do
    with {:ok, community} <- Communities.get_community(id: id, archived_at: nil),
         true <- Communities.readable?(community, auth) do
      {:ok, community}
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  # Held or removed posts are seen only by their author and moderators
  defp find_post(id, auth) do
    with {:ok, post} <- Forum.get_post(id: id),
         {:ok, _community} <- find_community(post.community_id, auth),
         true <- Forum.visible?(auth, post) do
      {:ok, post}
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  defp find_reply(nil), do: {:ok, nil}
  defp find_reply(id), do: Forum.get_reply(id)

  defp transcripts(auth, post) do
    case Transcripts.for_post(auth, post) do
      nil -> %{}
      summary -> %{post.id => summary}
    end
  end
end
