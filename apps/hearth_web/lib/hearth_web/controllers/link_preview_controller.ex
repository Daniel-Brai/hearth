defmodule HearthWeb.LinkPreviewController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules

  alias Hearth.Media
  alias Plug.Conn

  tags ["Media"]

  operation :show,
    summary: "Preview a link",
    description: "Private addresses, and sites without preview tags, are not found",
    security: [%{"bearer" => []}],
    parameters: [url: [in: :query, required: true, schema: %{type: :string, maxLength: 2_000}]],
    responses: [
      ok: {Schema.LinkPreview, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"}
    ]

  rate_limit :show, limit: 120, scale: :timer.minutes(1), by: :user

  @validate %{"url" => ~V[required|string|max:2000]}

  def show(%Conn{assigns: %{auth: %{}}} = conn, %{"url" => url}) do
    with {:ok, preview} <- Media.link_preview(url) do
      render(conn, :show, preview: preview)
    end
  end
end
