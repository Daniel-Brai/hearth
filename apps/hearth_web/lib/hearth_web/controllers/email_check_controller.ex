defmodule HearthWeb.EmailCheckController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules

  alias Hearth.Common
  alias Plug.Conn

  tags ["Communities"]

  operation :create,
    summary: "Check addresses can receive email",
    description: "Never says who has an account",
    security: [%{"bearer" => []}],
    request_body: Schema.EmailCheckBody,
    responses: [
      ok: {%{type: :array, items: Schema.EmailCheck}, description: "OK"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  rate_limit :create, limit: 60, scale: :timer.minutes(10), by: :user

  @validate %{
    "emails" => ~V[required|list|min:1|max:50],
    "emails.*" => ~V[required|string|min:1|max:254]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, %{"emails" => emails}) do
    checks =
      emails
      |> Enum.uniq()
      |> Task.async_stream(&{&1, Common.email_status(&1)},
        timeout: :infinity,
        max_concurrency: 10
      )
      |> Enum.map(fn {:ok, {email, status}} -> %{email: email, status: status} end)

    render(conn, :create, checks: checks)
  end
end
