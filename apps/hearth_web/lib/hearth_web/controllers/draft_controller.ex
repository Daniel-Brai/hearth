defmodule HearthWeb.DraftController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Plug.Conn

  tags ["Forum"]

  @community [in: :path, schema: %{type: :string, format: :uuid}]

  operation :index,
    summary: "List my unfinished posts",
    description: "One per community",
    security: [%{"bearer" => []}],
    responses: [
      ok: {%{type: :array, items: Schema.Draft}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def index(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    render(conn, :index, drafts: Forum.list_drafts(auth))
  end

  operation :update,
    summary: "Save my unfinished post in a community",
    security: [%{"bearer" => []}],
    parameters: [community_id: @community],
    request_body: Schema.DraftBody,
    responses: [
      ok: {Schema.Draft, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "title" => ~V[string|max:150],
    "body" => ~V[string|max:40000],
    "kind_id" => ~V[uuid]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => community_id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    changes = params |> Map.take(~w[title body kind_id]) |> Common.atomize_string_keys()

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, draft} <- Forum.save_draft(auth, community, changes) do
      render(conn, :show, draft: draft)
    end
  end

  operation :delete,
    summary: "Throw away my unfinished post in a community",
    security: [%{"bearer" => []}],
    parameters: [community_id: @community],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[required|uuid]}

  def delete(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => community_id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, community} <- Communities.get_community(id: community_id) do
      :ok = Forum.discard_draft(auth, community)
      send_resp(conn, :no_content, "")
    end
  end
end
