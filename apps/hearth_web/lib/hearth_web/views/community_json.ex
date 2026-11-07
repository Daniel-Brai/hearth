defmodule HearthWeb.CommunityJSON do
  alias Hearth.Events
  alias Hearth.Forum
  alias HearthWeb.CommunityRequestJSON
  alias HearthWeb.RoomJSON
  alias HearthWeb.UserJSON

  @fields ~w[
    id
    slug
    name
    tagline
    description
    hue
    logo_id
    banner_id
    visibility
    moderation
    welcome_message
    template
    owner_id
  ]a

  def index(%{communities: communities}), do: Enum.map(communities, &serialize/1)

  def create(%{request: request, people: people}),
    do: CommunityRequestJSON.serialize(request, people)

  def create(%{community: community}), do: serialize(community)

  def show(%{community: community, kinds: kinds, membership: membership}) do
    %{
      community: serialize(community),
      kinds: Enum.map(kinds, &kind/1),
      membership: membership(membership)
    }
  end

  def outline(%{community: community}) do
    %{
      community:
        community
        |> serialize()
        |> Map.merge(%{
          description: nil,
          welcome_message: nil,
          links: [],
          rooms: [],
          room_groups: []
        }),
      kinds: [],
      membership: nil
    }
  end

  def update(%{community: community}), do: serialize(community)

  def slug(%{slug: slug}), do: %{slug: slug}

  def join(%{membership: membership}), do: membership(membership)

  @spec serialize(map()) :: map()
  def serialize(community) do
    community
    |> Map.take(@fields)
    |> Map.merge(
      Map.take(community, ~w[logo_url banner_url member_count online_count categories]a)
    )
    |> Map.put(:owner, UserJSON.summary(community.owner))
    |> Map.put(:links, Enum.map(community.links, &Map.take(&1, [:url, :label])))
    |> Map.put(
      :rooms,
      community.rooms |> Enum.reject(& &1.archived_at) |> Enum.map(&RoomJSON.serialize/1)
    )
    |> Map.put(
      :room_groups,
      community |> Map.get(:room_groups, []) |> Enum.map(&RoomJSON.group/1)
    )
  end

  defp kind(kind) do
    Map.take(
      kind,
      ~w[id key label icon hue description title_hint body_hint answers postable position]a
    )
  end

  defp membership(nil), do: nil

  defp membership(membership) do
    %{
      roles: Enum.map(membership.roles, &Map.take(&1, ~w[key name color]a)),
      permissions: membership.permissions,
      joined_at: membership.joined_at
    }
  end

  def save_kinds(%{kinds: kinds}), do: Enum.map(kinds, &kind/1)

  def members(%{users: users, roles: roles}),
    do: Enum.map(users, &%{user: UserJSON.summary(&1), role_keys: Map.get(roles, &1.id, [])})

  def templates(%{templates: templates}), do: Enum.map(templates, &template/1)

  defp template(template) do
    template
    |> Map.take(~w[id label icon description category rooms voice placeholder]a)
    |> Map.merge(%{kinds: Forum.template_kinds(template.id), event: event(template.id)})
  end

  defp event(template) do
    case Events.template_event(template) do
      nil -> nil
      event -> Map.take(event, ~w[title days mins repeat]a)
    end
  end
end
