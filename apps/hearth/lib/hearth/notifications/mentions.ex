defmodule Hearth.Notifications.Mentions do
  alias Hearth.Accounts
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.Notifications
  alias Hearth.Notifications.Notices

  # More than this is someone pinging a crowd
  @most 10

  # Returns who it was meant for, whatever their own settings
  @spec notify(map(), [T.id()]) :: [T.id()]
  def notify(%{actor: actor, community: community, body: body} = mention, skip \\ []) do
    skip = [actor.id | skip]

    body
    |> Common.mentions()
    |> Enum.take(@most)
    |> Accounts.list_users_by_username()
    |> Enum.filter(&(&1.id not in skip and reaches?(&1, community, mention[:room])))
    |> Enum.map(fn user ->
      Notifications.send(user, Notices.mention(mention))
      user.id
    end)
  end

  defp reaches?(user, community, nil), do: IAM.member?(user, community.id)
  defp reaches?(user, _community, room), do: Communities.room_visible?(user, room)
end
