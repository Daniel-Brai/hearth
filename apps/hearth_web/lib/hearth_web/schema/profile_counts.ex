defmodule HearthWeb.Schema.ProfileCounts do
  use JSV.Schema

  defschema %{
    title: "ProfileCounts",
    type: :object,
    description: "Removed, held and deleted posts and replies don't count",
    required: ~w[posts answers people_helped]a,
    properties: %{
      posts: non_neg_integer(),
      answers: non_neg_integer(),
      people_helped: non_neg_integer(description: "Distinct people who marked it helpful")
    }
  }
end
