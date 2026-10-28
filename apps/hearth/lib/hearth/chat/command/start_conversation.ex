defmodule Hearth.Chat.Command.StartConversation do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Chat.Conversation
  alias Hearth.Chat.ConversationMember
  alias Hearth.Repo

  @spec execute(User.t(), [User.t()], keyword()) ::
          {:ok, Conversation.t()} | {:error, Changeset.t()}
  def execute(%User{} = user, others, attrs) when is_list(others) do
    now = DateTime.utc_now()
    conversation = struct!(%Conversation{created_by_id: user.id}, attrs)

    Repo.transact(fn ->
      with {:ok, conversation} <- Conversation.insert(conversation, Map.new(attrs)) do
        Repo.insert_all(ConversationMember, rows(conversation, [user | others], now))
        {:ok, Repo.preload(conversation, :members)}
      end
    end)
  end

  defp rows(conversation, members, now) do
    for member <- members do
      %{conversation_id: conversation.id, user_id: member.id, inserted_at: now, updated_at: now}
    end
  end
end
