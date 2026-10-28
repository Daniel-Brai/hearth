defmodule HearthWeb.CommunityMemberController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.IAM
  alias HearthWeb.Avatars
  alias HearthWeb.PublicProfile
  alias Plug.Conn

  tags ["Communities"]

  operation :index,
    summary: "Find members of a community to mention",
    description: "Matches the start of a username or any part of a name",
    parameters: [
      community_id: [in: :path, schema: %{type: :string, format: :uuid}],
      q: [in: :query, schema: %{type: :string, maxLength: 40}],
      limit: [in: :query, schema: %{type: :integer, minimum: 1, maximum: 20}]
    ],
    responses: [
      ok: {%{type: :array, items: Schema.MemberMatch}, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "q" => ~V[string|max:40],
    "limit" => ~V[between:1,20]
  }

  def index(%Conn{assigns: %{auth: auth}} = conn, %{"community_id" => community_id} = params) do
    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         true <- Communities.readable?(community, auth) do
      roles = IAM.member_roles(community.id)

      users =
        (params["q"] || "")
        |> Accounts.search_users(Map.keys(roles), query_param(conn, :limit) || 8)
        |> Avatars.put_urls()
        |> Enum.map(&PublicProfile.apply(&1, auth))

      render(conn, :index, users: users, roles: roles)
    else
      false -> {:error, :not_found}
      error -> error
    end
  end
end
