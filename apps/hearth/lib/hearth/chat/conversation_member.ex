defmodule Hearth.Chat.ConversationMember do
  use Hearth.Repo.Schema, prefix: "chat", primary_key: false

  alias Hearth.Chat.Conversation
  alias Hearth.Common.T

  schema "conversation_members" do
    belongs_to :conversation, Conversation, primary_key: true
    field :user_id, Ecto.UUID, primary_key: true
    field :last_read_message_id, Ecto.UUID
    field :muted, :boolean, default: false

    timestamps()
  end

  @type t :: %__MODULE__{
          conversation_id: T.id(),
          user_id: T.id(),
          last_read_message_id: nil | T.id(),
          muted: boolean()
        }

  @spec member?(T.id(), T.id()) :: boolean()
  def member?(conversation_id, user_id) do
    exists?(conversation_id: conversation_id, user_id: user_id)
  end
end
