defmodule HearthWeb.MediaController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Media
  alias Plug.Conn

  tags ["Media"]

  parameter(:id, in: :path, schema: %{type: :string, format: :uuid})

  operation :show,
    summary: "Show a file",
    description: "Only its uploader can see it",
    security: [%{"bearer" => []}],
    responses: [
      ok: {Schema.Media, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def show(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, media} <- Media.fetch_own_media(auth, id) do
      render(conn, :show, media: media)
    end
  end

  operation :delete,
    summary: "Delete a file",
    security: [%{"bearer" => []}],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def delete(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, media} <- Media.fetch_own_media(auth, id),
         {:ok, _deleted} <- Media.delete_media(auth, media) do
      send_resp(conn, :no_content, "")
    end
  end
end
