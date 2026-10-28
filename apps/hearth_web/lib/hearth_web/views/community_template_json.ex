defmodule HearthWeb.CommunityTemplateJSON do
  alias Hearth.Events
  alias Hearth.Forum

  @fields ~w[id label icon description category rooms voice placeholder]a

  def index(%{templates: templates}), do: Enum.map(templates, &serialize/1)

  defp serialize(template) do
    template
    |> Map.take(@fields)
    |> Map.merge(%{kinds: Forum.template_kinds(template.id), event: event(template.id)})
  end

  defp event(template) do
    case Events.template_event(template) do
      nil -> nil
      event -> Map.take(event, ~w[title days mins repeat]a)
    end
  end
end
