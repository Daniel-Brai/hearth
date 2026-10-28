defmodule HearthWeb.Schema.SignUp do
  use JSV.Schema

  defschema %{
    title: "SignUp",
    type: :object,
    required: [:sign_up_token],
    properties: %{
      sign_up_token: string(description: "Good for 60 minutes")
    }
  }
end
