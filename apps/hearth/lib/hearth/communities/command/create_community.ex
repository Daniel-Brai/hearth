defmodule Hearth.Communities.Command.CreateCommunity do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Communities.Community
  alias Hearth.Communities.CommunityCategory
  alias Hearth.Communities.Room
  alias Hearth.Communities.Template
  alias Hearth.IAM
  alias Hearth.Repo

  @spec execute(User.t(), map(), nil | User.t()) ::
          {:ok, Community.t()}
          | {:error, :too_many_categories | :unknown_category | Changeset.t()}
  def execute(%User{} = owner, %{} = params, creator \\ nil) do
    creator = creator || owner
    community = %Community{owner_id: owner.id, creator_id: creator.id}

    Repo.transact(fn ->
      with {:ok, community} <- Community.insert(community, params),
           {:ok, _roles} <- IAM.create_default_roles(community.id),
           {:ok, _membership} <- IAM.join(owner, community.id, ["owner"]),
           {:ok, rooms} <- create_rooms(community),
           :ok <- CommunityCategory.put(community, categories(community, params)) do
        {:ok, %{community | rooms: rooms}}
      end
    end)
  end

  # With none picked a community starts in its template's category
  defp categories(community, params) do
    case params[:categories] || Template.get(community.template).category do
      nil -> nil
      slug when is_binary(slug) -> [slug]
      slugs -> slugs
    end
  end

  defp create_rooms(community) do
    template = Template.get(community.template)

    text = Enum.map(template.rooms, &%{type: :text, name: &1})
    voice = if template.voice, do: [%{type: :voice, name: template.voice}], else: []

    result =
      (text ++ voice)
      |> Enum.with_index()
      |> Enum.reduce_while({:ok, []}, &insert_room(community, &1, &2))

    with {:ok, rooms} <- result, do: {:ok, Enum.reverse(rooms)}
  end

  defp insert_room(community, {params, position}, {:ok, rooms}) do
    room = %Room{community_id: community.id}

    case Room.insert(room, Map.put(params, :position, position)) do
      {:ok, room} -> {:cont, {:ok, [room | rooms]}}
      {:error, changeset} -> {:halt, {:error, changeset}}
    end
  end
end
