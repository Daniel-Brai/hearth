defmodule HearthWeb.CommunityTemplateController do
  use HearthWeb, :api_controller

  alias Hearth.Communities

  tags ["Communities"]

  operation :index,
    summary: "List the starting points for a new community",
    description: "Cacheable for an hour",
    responses: [ok: {%{type: :array, items: Schema.CommunityTemplate}, description: "OK"}]

  def index(conn, _params) do
    conn
    |> put_resp_header("cache-control", "public, max-age=3600")
    |> render(:index, templates: Communities.list_templates())
  end
end
