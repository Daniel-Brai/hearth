defmodule HearthWeb.PublicProfile do
  alias Hearth.IAM

  @spec apply(map(), nil | map()) :: map()
  def apply(%{id: id} = user, %{id: id}), do: user

  def apply(user, viewer) do
    user
    |> hide_name()
    |> hide_photo(viewer)
  end

  defp hide_name(%{privacy: %{show_name: false}} = user),
    do: %{user | display_name: nil, location: nil}

  defp hide_name(user), do: user

  defp hide_photo(%{privacy: %{avatar: :everyone}} = user, _viewer), do: user

  defp hide_photo(%{privacy: %{avatar: :members}} = user, %{} = viewer) do
    case IAM.share_community?(user, viewer) do
      true -> user
      false -> no_photo(user)
    end
  end

  defp hide_photo(user, _viewer), do: no_photo(user)

  defp no_photo(user), do: Map.merge(user, %{avatar_id: nil, avatar_url: nil})
end
