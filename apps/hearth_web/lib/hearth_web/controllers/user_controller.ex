defmodule HearthWeb.UserController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.IAM
  alias HearthWeb.Attachments
  alias HearthWeb.Authors
  alias HearthWeb.Avatars
  alias HearthWeb.Paging
  alias HearthWeb.Presence
  alias HearthWeb.PublicProfile
  alias HearthWeb.Reports
  alias Plug.Conn

  tags ["People"]

  operation :index,
    summary: "List people",
    description:
      "By usernames, which works signed out, or else everyone who shares a community with me, online first",
    parameters: [
      usernames: [
        in: :query,
        schema: %{type: :string, maxLength: 1_100},
        description: "Up to 50, separated by commas. Names with no account are left out"
      ],
      q: [in: :query, schema: %{type: :string, maxLength: 40}],
      community: [in: :query, schema: %{type: :string, format: :uuid}],
      limit: [in: :query, schema: %{type: :integer, minimum: 1, maximum: 100, default: 50}]
    ],
    responses: [
      ok: {%{type: :array, items: Schema.Person}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "usernames" => ~V[string|max:1100],
    "q" => ~V[string|max:40],
    "community" => ~V[uuid],
    "limit" => ~V[between:1,100]
  }

  def index(%Conn{assigns: %{auth: auth}} = conn, %{"usernames" => usernames}) do
    people =
      usernames
      |> String.split(",", trim: true)
      |> Enum.take(50)
      |> Accounts.list_users_by_username()
      |> Avatars.put_urls()
      |> Enum.map(&PublicProfile.apply(&1, auth))

    render(conn, :index, people: people, shared: shared_with(auth, nil), online: online())
  end

  def index(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    shared = shared_with(auth, params["community"])
    online = Presence.online_ids()

    people =
      (params["q"] || "")
      |> Accounts.list_people(Map.keys(shared), online, query_param(conn, :limit) || 50)
      |> Avatars.put_urls()
      |> Enum.map(&PublicProfile.apply(&1, auth))

    render(conn, :index, people: people, shared: shared, online: MapSet.new(online))
  end

  def index(%Conn{}, _params), do: {:error, :unauthorized}

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

  operation :available,
    summary: "Check whether a username is free",
    description: "A username that breaks the rules is not available",
    parameters: [
      username: [
        in: :query,
        required: true,
        schema: %{type: :string, minLength: 1, maxLength: 40}
      ]
    ],
    responses: [
      ok: {Schema.UsernameAvailability, description: "OK"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"}
    ]

  rate_limit :available, limit: 60, scale: :timer.minutes(1)

  @validate %{"username" => ~V[required|string|min:1|max:40]}

  def available(conn, %{"username" => username}) do
    render(conn, :available, available: Accounts.username_available?(username))
  end

  defp shared_with(nil, _community_id), do: %{}
  defp shared_with(auth, community_id), do: IAM.co_members(auth, community_id)

  defp online, do: MapSet.new(Presence.online_ids())
end
