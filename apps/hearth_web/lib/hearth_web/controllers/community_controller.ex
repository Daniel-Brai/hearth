defmodule HearthWeb.CommunityController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.IAM
  alias HearthWeb.Authors
  alias HearthWeb.CommunityExtras
  alias HearthWeb.CommunityRequestJSON
  alias Plug.Conn

  tags ["Communities"]

  @id [
    in: :path,
    schema: %{type: :string, minLength: 1, maxLength: 80},
    description: "Id or slug."
  ]

  operation :index,
    summary: "List the communities I'm in",
    security: [%{"bearer" => []}],
    responses: [
      ok: {%{type: :array, items: Schema.Community}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def index(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    render(conn, :index,
      communities: auth |> Communities.list_joined() |> CommunityExtras.put(auth)
    )
  end

  operation :public,
    summary: "List the public communities",
    description: "Needs no sign in",
    responses: [
      ok: {%{type: :array, items: Schema.Community}, description: "OK"}
    ]

  def public(%Conn{} = conn, _params) do
    render(conn, :index, communities: CommunityExtras.put(Communities.list_public(), nil))
  end

  operation :create,
    summary: "Start a community",
    description: "Where the instance takes requests this files one and answers 202",
    security: [%{"bearer" => []}],
    request_body: Schema.CreateCommunityBody,
    responses: [
      created: {Schema.Community, description: "Created"},
      accepted: {Schema.CommunityRequest, description: "Requested"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "name" => ~V[required|string|min:2|max:60],
    "tagline" => ~V[string|max:120],
    "description" => ~V[string|max:2000],
    "logo_id" => ~V[uuid],
    "hue" => ~V[allowed:ink,blue,violet,purple,pink,red,orange,yellow,green,aqua],
    "visibility" => ~V[allowed:public_indexed,public,invite_only,private],
    "template" => ~V[template],
    "note" => ~V[string|max:1000],
    "categories" => ~V[list|max:2],
    "categories.*" => ~V[category]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    attrs =
      params
      |> Map.take(~w[name tagline description logo_id hue visibility template note categories])
      |> Common.atomize_string_keys()

    case Communities.start_community(auth, attrs) do
      {:ok, community} ->
        {:ok, community} = Communities.get_community(id: community.id, preload: :rooms)

        conn
        |> put_status(:created)
        |> render(:create, community: CommunityExtras.put_one(community, auth))

      {:requested, request} ->
        conn
        |> put_status(:accepted)
        |> put_view(CommunityRequestJSON)
        |> render(:show, request: request, people: Authors.people([request.requester_id]))

      error ->
        error
    end
  end

  operation :slug,
    summary: "Show the address a new community would get",
    description: "A taken one gets the next number",
    security: [%{"bearer" => []}],
    parameters: [name: [in: :query, required: true, schema: %{type: :string, maxLength: 60}]],
    responses: [
      ok: {Schema.CommunitySlug, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"name" => ~V[required|string|max:60]}

  def slug(%Conn{assigns: %{auth: %{}}} = conn, %{"name" => name}) do
    render(conn, :slug, slug: Communities.slug_for(name))
  end

  operation :show,
    summary: "Show a community",
    description: "Outsiders see only the name, tagline and look of an invite only community",
    parameters: [id: @id],
    responses: [
      ok: {Schema.CommunityDetail, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|string|min:1|max:80]}

  def show(%Conn{assigns: %{auth: auth}} = conn, %{"id" => id}) do
    with {:ok, community} <- find_visible(id, auth) do
      community = CommunityExtras.put_one(community, auth)

      if Communities.readable?(community, auth) do
        render(conn, :show,
          community: community,
          kinds: Forum.list_kinds(community.id),
          membership: membership(auth, community)
        )
      else
        render(conn, :outline, community: community)
      end
    end
  end

  operation :update,
    summary: "Change a community",
    description: "Needs community.update",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.UpdateCommunityBody,
    responses: [
      ok: {Schema.Community, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|string|min:1|max:80],
    "name" => ~V[string|min:2|max:60],
    "tagline" => ~V[string|max:120],
    "description" => ~V[string|max:4000],
    "hue" => ~V[allowed:ink,blue,violet,purple,pink,red,orange,yellow,green,aqua],
    "logo_id" => ~V[uuid],
    "banner_id" => ~V[uuid],
    "welcome_message" => ~V[string|max:2000],
    "visibility" => ~V[allowed:public_indexed,public,invite_only,private],
    "links" => ~V[list|max:10],
    "links.*.url" => ~V[required|string|max:2000],
    "links.*.label" => ~V[string|max:40],
    "categories" => ~V[list|max:2],
    "categories.*" => ~V[category]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    changes =
      params
      |> Map.take(
        ~w[name tagline description hue logo_id banner_id welcome_message visibility links categories]
      )
      |> Common.atomize_string_keys()

    with {:ok, community} <- find_visible(id, auth),
         {:ok, community} <- Communities.update_community(auth, community, changes) do
      render(conn, :update, community: CommunityExtras.put_one(community, auth))
    end
  end

  operation :join,
    summary: "Join an open community",
    description: "An invite only community is joined through its invite",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      created: {Schema.Membership, description: "Joined"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|string|min:1|max:80]}

  def join(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, community} <- find_visible(id, auth),
         {:ok, _membership} <- Communities.join(auth, community),
         {:ok, membership} <- IAM.get_membership(auth, community.id) do
      conn |> put_status(:created) |> render(:join, membership: membership)
    end
  end

  operation :leave,
    summary: "Leave a community",
    description: "The Owner can't leave",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|string|min:1|max:80]}

  def leave(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, community} <- find_visible(id, auth),
         :ok <- Communities.leave(auth, community) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :transfer_code,
    summary: "Email the Owner a code to hand over a community",
    description: "Only the Owner can and the code works once for 15 minutes",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|string|min:1|max:80]}

  def transfer_code(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, community} <- find_visible(id, auth),
         :ok <- Communities.request_transfer_code(auth, community) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :transfer,
    summary: "Hand a community to another member",
    description: "Needs the emailed code and the Owner becomes a Moderator or Maintainer",
    security: [%{"bearer" => []}],
    parameters: [id: @id],
    request_body: Schema.TransferBody,
    responses: [
      ok: {Schema.Community, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|string|min:1|max:80],
    "user_id" => ~V[required|uuid],
    "code" => ~V[required|string|size:6]
  }

  def transfer(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"id" => id, "user_id" => user_id, "code" => code} = params

    with {:ok, community} <- find_visible(id, auth),
         {:ok, to} <- Accounts.get_user(id: user_id),
         {:ok, community} <- Communities.transfer_ownership(auth, community, to, code) do
      {:ok, community} = Communities.get_community(id: community.id, preload: :rooms)
      render(conn, :update, community: CommunityExtras.put_one(community, auth))
    else
      {:error, :invalid} -> {:error, :invalid_code}
      {:error, :expired} -> {:error, :expired_code}
      error -> error
    end
  end

  defp find_visible(id_or_slug, auth) do
    by = if Common.valid_id?(id_or_slug), do: [id: id_or_slug], else: [slug: id_or_slug]

    with {:ok, community} <- Communities.get_community([archived_at: nil, preload: :rooms] ++ by),
         true <- Communities.visible?(community, auth) do
      {:ok, community}
    else
      false -> {:error, :not_found}
      error -> error
    end
  end

  defp membership(nil, _community), do: nil

  defp membership(auth, community) do
    case IAM.get_membership(auth, community.id) do
      {:ok, membership} -> membership
      {:error, :not_found} -> nil
    end
  end
end
