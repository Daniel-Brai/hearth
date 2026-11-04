defmodule HearthWeb.Schema.InviteEmail do
  use JSV.Schema

  alias Hearth.Communities
  alias HearthWeb.Schema

  defschema %{
    title: "InviteEmail",
    type: :object,
    required: ~w[id email role_key status inserted_at]a,
    properties: %{
      id: uuid(),
      email: string(),
      role_key: string(),
      status: Schema.enum_of(Communities.InviteEmail, :status),
      inserted_at: string(format: :"date-time")
    }
  }
end
