defmodule HearthWeb.Avatars do
  alias Hearth.Media

  @spec put_urls([map()]) :: [map()]
  def put_urls(users) when is_list(users) do
    urls = users |> Enum.map(& &1.avatar_id) |> Media.avatar_urls()

    Enum.map(users, &Map.put(&1, :avatar_url, urls[&1.avatar_id]))
  end

  @spec put_url(map()) :: map()
  def put_url(user), do: [user] |> put_urls() |> hd()
end
