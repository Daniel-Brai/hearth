defmodule HearthWeb.ReportController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Common
  alias Hearth.Moderation
  alias Plug.Conn

  tags ["Moderation"]

  operation :create,
    summary: "Report a post, reply or message",
    description:
      "Direct messages go to the instance admins and it fails with reports_off, own or already_reported",
    security: [%{"bearer" => []}],
    request_body: Schema.ReportBody,
    responses: [
      created: {Schema.ReportReceipt, description: "Created"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "subject_type" => ~V[required|allowed:post,reply,message],
    "subject_id" => ~V[required|uuid],
    "reason" => ~V[required|allowed:spam,harassment,hate,sexual,violence,off_topic,other],
    "note" => ~V[string|max:1000]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"subject_type" => type, "subject_id" => id, "reason" => reason} = params

    attrs = %{reason: Common.to_atom(reason), note: params["note"]}

    with {:ok, _item} <- Moderation.report(auth, Common.to_atom(type), id, attrs) do
      conn
      |> put_status(:created)
      |> render(:create, %{})
    end
  end
end
