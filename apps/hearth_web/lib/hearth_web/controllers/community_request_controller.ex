defmodule HearthWeb.CommunityRequestController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias HearthWeb.Authors
  alias Plug.Conn

  tags ["Communities"]

  operation :index,
    summary: "List community requests",
    description: "Needs an instance admin",
    security: [%{"bearer" => []}],
    parameters: [
      status: [
        in: :query,
        schema: %{type: :string, enum: ~w[pending approved declined], default: "pending"}
      ]
    ],
    responses: [
      ok: {%{type: :array, items: Schema.CommunityRequest}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"status" => ~V[allowed:pending,approved,declined]}

  def index(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    status = Common.to_atom(params["status"] || :pending)

    with {:ok, requests} <- Communities.list_requests(auth, status) do
      ids = Enum.map(requests, & &1.requester_id)
      render(conn, :index, requests: requests, people: Authors.people(ids))
    end
  end

  operation :decide,
    summary: "Approve or decline a community request",
    description: "Needs an instance admin and approving starts the community",
    security: [%{"bearer" => []}],
    parameters: [id: [in: :path, schema: %{type: :string, format: :uuid}]],
    request_body: Schema.DecisionBody,
    responses: [
      ok: {Schema.CommunityRequest, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "id" => ~V[required|uuid],
    "decision" => ~V[required|allowed:approved,declined]
  }

  def decide(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id, "decision" => decision}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, request} <- Communities.get_request(id),
         {:ok, request} <- Communities.decide_request(auth, request, Common.to_atom(decision)),
         {:ok, request} <- Communities.get_request(request.id) do
      render(conn, :show, request: request, people: Authors.people([request.requester_id]))
    end
  end
end
