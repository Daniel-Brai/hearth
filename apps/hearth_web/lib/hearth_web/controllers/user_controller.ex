defmodule HearthWeb.UserController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.Forum
  alias HearthWeb.Attachments
  alias HearthWeb.Authors
  alias HearthWeb.Avatars
  alias HearthWeb.Paging
  alias HearthWeb.PublicProfile
  alias HearthWeb.Reports
  alias Plug.Conn

  tags ["People"]

  operation :index,
    summary: "Look up people by username",
    description: "Names with no account are left out",
    parameters: [
      usernames: [
        in: :query,
        required: true,
        schema: %{type: :string, maxLength: 1_100},
        description: "Up to 50, separated by commas."
      ]
    ],
    responses: [
      ok: {%{type: :array, items: Schema.UserSummary}, description: "OK"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"usernames" => ~V[required|string|max:1100]}

  def index(%Conn{assigns: %{auth: auth}} = conn, %{"usernames" => usernames}) do
    usernames =
      usernames
      |> String.split(",", trim: true)
      |> Enum.take(50)

    users =
      usernames
      |> Accounts.list_users_by_username()
      |> Avatars.put_urls()
      |> Enum.map(&PublicProfile.apply(&1, auth))

    render(conn, :index, users: users)
  end

  @username [in: :path, schema: %{type: :string, maxLength: 40}]

  operation :show,
    summary: "Show a person's profile",
    description: "Counts only what the person asking may see",
    parameters: [username: @username],
    responses: [
      ok: {Schema.Profile, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"username" => ~V[required|string|max:40]}

  def show(%Conn{assigns: %{auth: auth}} = conn, %{"username" => username}) do
    with {:ok, user} <- Accounts.get_user(username: username, deleted_at: nil) do
      render(conn, :show,
        user: user |> Avatars.put_url() |> PublicProfile.apply(auth),
        counts: Forum.author_counts(user.id, Communities.readable_ids(auth))
      )
    end
  end

  operation :posts,
    summary: "List what someone posted",
    description: "Newest first, only in communities the person asking may read",
    parameters: [username: @username] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.Post), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "username" => ~V[required|string|max:40],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def posts(%Conn{assigns: %{auth: auth}} = conn, %{"username" => username}) do
    with {:ok, user} <- Accounts.get_user(username: username, deleted_at: nil),
         readable = Communities.readable_ids(auth),
         %{data: posts} = page <- Forum.list_author_posts(user.id, readable, Paging.opts(conn)) do
      render(conn, :posts,
        page: page,
        authors: Authors.load(posts),
        attachments: Attachments.load(posts, :post),
        reported: Reports.load(posts, auth, :post),
        in_review: Reports.in_review(posts, :post),
        watching: Forum.watched(auth, posts)
      )
    end
  end

  operation :replies,
    summary: "List what someone replied",
    description: "Newest first, only in communities the person asking may read",
    parameters: [username: @username] ++ Schema.paging(),
    responses: [
      ok: {Schema.page(Schema.AuthoredReply), description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "username" => ~V[required|string|max:40],
    "limit" => ~V[between:1,50],
    "after" => ~V[string],
    "before" => ~V[string]
  }

  def replies(%Conn{assigns: %{auth: auth}} = conn, %{"username" => username}) do
    with {:ok, user} <- Accounts.get_user(username: username, deleted_at: nil),
         readable = Communities.readable_ids(auth),
         %{data: replies} = page <-
           Forum.list_author_replies(user.id, readable, Paging.opts(conn)) do
      render(conn, :replies,
        page: page,
        posts: replies |> Enum.map(& &1.post_id) |> Forum.list_posts_by_id(),
        authors: Authors.load(replies),
        attachments: Attachments.load(replies, :reply)
      )
    end
  end
end
