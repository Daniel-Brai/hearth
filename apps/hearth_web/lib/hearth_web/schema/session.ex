defmodule HearthWeb.Schema.Session do
  use JSV.Schema

  alias HearthWeb.Schema.Me

  defschema %{
    title: "Session",
    type: :object,
    description: "The refresh token comes as an HttpOnly cookie",
    required: ~w[access_token token_type expires_in user]a,
    properties: %{
      access_token: string(),
      token_type: const("Bearer"),
      expires_in: pos_integer(description: "In seconds"),
      user: Me
    }
  }
end
