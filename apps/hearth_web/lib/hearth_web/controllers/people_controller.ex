defmodule HearthWeb.PeopleController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.IAM
  alias HearthWeb.Avatars
  alias HearthWeb.Presence
  alias HearthWeb.PublicProfile
  alias Plug.Conn

  tags ["Accounts"]

  operation :index,
    summary: "List people who share a community with me",
    description: "Online first with each person's privacy settings applied",
    security: [%{"bearer" => []}],
    parameters: [
      q: [in: :query, schema: %{type: :string, maxLength: 40}],
      community: [in: :query, schema: %{type: :string, format: :uuid}],
      limit: [in: :query, schema: %{type: :integer, minimum: 1, maximum: 100, default: 50}]
    ],
    responses: [
      ok: {%{type: :array, items: Schema.Person}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"q" => ~V[string|max:40], "community" => ~V[uuid], "limit" => ~V[between:1,100]}

  def index(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    shared = IAM.co_members(auth, params["community"])
    online = Presence.online_ids()
    limit = query_param(conn, :limit) || 50

    people =
      (params["q"] || "")
      |> Accounts.list_people(Map.keys(shared), online, limit)
      |> Avatars.put_urls()
      |> Enum.map(&PublicProfile.apply(&1, auth))

    render(conn, :index, people: people, shared: shared, online: MapSet.new(online))
  end
end
