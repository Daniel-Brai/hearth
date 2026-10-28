defmodule HearthWeb.AuthJSON do
  @me ~w[
    id
    username
    display_name
    email
    avatar_id
    avatar_url
    bio
    pronouns
    location
    timezone
    locale
    is_instance_admin
  ]a

  def sign_in(%{sign_up_token: token}), do: %{sign_up_token: token}
  def sign_in(assigns), do: session(assigns)

  def register(assigns), do: session(assigns)

  def refresh(assigns), do: session(assigns)

  def update_me(%{user: user}), do: serialize(user)

  def me(%{user: user}), do: serialize(user)

  def update_settings(%{settings: settings}), do: Map.from_struct(settings)

  @spec serialize(map()) :: map()
  def serialize(user) do
    user
    |> Map.take(@me)
    |> Map.put(:links, Enum.map(user.links, &Map.take(&1, [:url, :label])))
    |> Map.put(:privacy, Map.from_struct(user.privacy))
    |> Map.put(:settings, Map.from_struct(user.settings))
  end

  defp session(%{user: user, access_token: token, expires_in: expires_in}) do
    %{access_token: token, token_type: "Bearer", expires_in: expires_in, user: serialize(user)}
  end
end
