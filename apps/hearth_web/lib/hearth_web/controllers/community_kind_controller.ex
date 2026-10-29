defmodule HearthWeb.CommunityKindController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Plug.Conn

  tags ["Communities"]

  @fields ~w[key label icon hue description title_hint body_hint answers postable]

  operation :update,
    summary: "Save a community's kinds of post",
    description:
      "Needs community.update. Kinds left out are removed and their posts move to Discussion",
    security: [%{"bearer" => []}],
    parameters: [community_id: [in: :path, schema: %{type: :string, format: :uuid}]],
    request_body: Schema.SaveKindsBody,
    responses: [
      ok: {%{type: :array, items: Schema.PostKind}, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "kinds" => ~V[required|list|max:8],
    "kinds.*.key" => ~V[string|max:40],
    "kinds.*.label" => ~V[required|string|max:30],
    "kinds.*.icon" => ~V[required|string|max:40],
    "kinds.*.hue" => ~V[required|string|max:20],
    "kinds.*.description" => ~V[string|max:300],
    "kinds.*.title_hint" => ~V[string|max:120],
    "kinds.*.body_hint" => ~V[string|max:2000],
    "kinds.*.answers" => ~V[boolean],
    "kinds.*.postable" => ~V[boolean]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => community_id} = params) do
    %Conn{assigns: %{auth: auth}} = conn
    kinds = Enum.map(params["kinds"], &(&1 |> Map.take(@fields) |> Common.atomize_string_keys()))

    with {:ok, community} <- find_visible(community_id, auth),
         {:ok, saved} <- Forum.save_kinds(auth, community, kinds) do
      render(conn, :update, kinds: saved)
    end
  end

  # A community the viewer can't know about answers not found, never forbidden
  defp find_visible(id, auth) do
    with {:ok, community} <- Communities.get_community(id: id, archived_at: nil),
         true <- Communities.visible?(community, auth) do
      {:ok, community}
    else
      false -> {:error, :not_found}
      error -> error
    end
  end
end
