defmodule Hearth.Notifications.Worker.TellRoom do
  use Oban.Worker,
    queue: :default,
    max_attempts: 5,
    unique: [period: 3_600, keys: [:message_id]]

  alias Hearth.Accounts
  alias Hearth.Chat
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.Notifications
  alias Hearth.Notifications.Notices

  @batch 500

  @spec enqueue(T.id(), String.t(), [T.id()]) :: {:ok, Oban.Job.t()} | {:error, term()}
  def enqueue(message_id, url, told) do
    %{message_id: message_id, url: url, told: told} |> new() |> Oban.insert()
  end

  # People named in the message were told already, so they get one notice
  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"message_id" => id, "url" => url, "told" => told}}) do
    with {:ok, message} <- Chat.get_message(id),
         {:ok, actor} <- Accounts.get_user(id: message.author_id),
         {:ok, room} <- Communities.get_room(id: message.room_id),
         {:ok, community} <- Communities.get_community(id: room.community_id) do
      notice =
        Notices.mention_all(%{
          actor: actor,
          community: community,
          room: room,
          message: message,
          url: url
        })

      community.id
      |> IAM.member_roles()
      |> Map.keys()
      |> Kernel.--([actor.id | told])
      |> Enum.chunk_every(@batch)
      |> Enum.each(&tell(&1, room, notice))
    end

    :ok
  end

  defp tell(user_ids, room, notice) do
    user_ids
    |> Accounts.list_users()
    |> Enum.reject(&Communities.room_hidden?(&1, room))
    |> Enum.each(&Notifications.send(&1, notice))
  end
end
