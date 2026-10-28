defmodule HearthWeb.NotificationJSON do
  alias HearthWeb.PageJSON
  alias HearthWeb.UserJSON

  @fields ~w[id kind community_id subject_type subject_id data read_at inserted_at]a

  def index(%{page: page, actors: actors, unread: unread}) do
    %{
      data: Enum.map(page.data, &serialize(&1, actors)),
      meta: PageJSON.meta(page.meta),
      unread: unread
    }
  end

  defp serialize(notification, actors) do
    notification
    |> Map.take(@fields)
    |> Map.put(:actor, UserJSON.summary(actors[notification.actor_id]))
  end
end
