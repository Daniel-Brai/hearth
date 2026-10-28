defmodule HearthWeb.CommunityRequestJSON do
  alias HearthWeb.UserJSON

  @fields ~w[
    id
    name
    tagline
    description
    hue
    visibility
    template
    note
    status
    community_id
    decided_at
    inserted_at
  ]a

  def index(%{requests: requests, people: people}),
    do: Enum.map(requests, &serialize(&1, people))

  def show(%{request: request, people: people}), do: serialize(request, people)

  defp serialize(request, people) do
    request
    |> Map.take(@fields)
    |> Map.put(:requester, UserJSON.summary(people[request.requester_id]))
    |> Map.put(:community_slug, community_slug(request.community))
  end

  # Only an approved request has its community loaded
  defp community_slug(%{slug: slug}), do: slug
  defp community_slug(_none), do: nil
end
