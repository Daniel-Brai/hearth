defmodule HearthWeb.CommunityKindJSON do
  @fields ~w[id key label icon hue description title_hint body_hint answers postable position]a

  def update(%{kinds: kinds}), do: Enum.map(kinds, &Map.take(&1, @fields))
end
