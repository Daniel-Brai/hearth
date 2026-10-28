defmodule HearthWeb.UsernameController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules

  alias Hearth.Accounts

  tags ["Auth"]

  operation :show,
    summary: "Check whether a username is free",
    description: "A username that breaks the rules is not available",
    parameters: [username: [in: :path, schema: %{type: :string, minLength: 1, maxLength: 40}]],
    responses: [
      ok: {Schema.UsernameAvailability, description: "OK"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"}
    ]

  rate_limit :show, limit: 60, scale: :timer.minutes(1)

  @validate %{"username" => ~V[required|string|min:1|max:40]}

  def show(conn, %{"username" => username}) do
    render(conn, :show, available: Accounts.username_available?(username))
  end
end
