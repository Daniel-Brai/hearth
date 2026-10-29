defmodule Hearth.Chat do
  events = [MessageCreated, MessageRemoved]

  default = [Conversation, Message | events]

  exports =
    case Mix.env() do
      :test -> default ++ [ConversationMember, Reaction, RoomRead]
      _env -> default
    end

  use Boundary,
    deps: [
      Hearth.Accounts,
      Hearth.Buffer,
      Hearth.Common,
      Hearth.Communities,
      Hearth.IAM,
      Hearth.Media,
      Hearth.PubSub,
      Hearth.Repo,
      Hearth.ScreeningPolicy,
      Hearth.Vault
    ],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Buffer
  alias Hearth.Chat.Command.DeleteMessage
  alias Hearth.Chat.Command.EditMessage
  alias Hearth.Chat.Command.SendMessage
  alias Hearth.Chat.Command.StartConversation
  alias Hearth.Chat.Conversation
  alias Hearth.Chat.ConversationMember
  alias Hearth.Chat.Message
  alias Hearth.Chat.MessageCreated
  alias Hearth.Chat.MessageEdited
  alias Hearth.Chat.MessageReacted
  alias Hearth.Chat.MessageRemoved
  alias Hearth.Chat.Reaction
  alias Hearth.Chat.ReadMarkers
  alias Hearth.Chat.RoomActivity
  alias Hearth.Chat.SoundPlayed
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.Communities.Room
  alias Hearth.IAM
  alias Hearth.PubSub
  alias Hearth.Repo.Page

  @topic "chat"

  @type place :: Room.t() | Conversation.t()

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec send_message(User.t(), place(), map()) ::
          {:ok, Message.t()}
          | {:error,
             :forbidden
             | :archived
             | :not_found
             | :pending
             | :too_many_attachments
             | :invalid_attachment
             | Changeset.t()}
  def send_message(%User{} = user, place, %{} = params) do
    reply_to_id = params[:reply_to_id] || params["reply_to_id"]
    kind = Map.get(params, :kind, :text)

    with :ok <- may_write(user, place),
         :ok <- may_say(user, place, kind),
         {:ok, parent} <- fetch_parent(place, reply_to_id),
         {:ok, message} <-
           SendMessage.execute(user, [kind: kind] ++ where_in(place), parent, params) do
      broadcast(%MessageCreated{
        message_id: message.id,
        room_id: message.room_id,
        conversation_id: message.conversation_id,
        author_id: user.id,
        reply_to_id: message.reply_to_id,
        reply_to_author_id: get_in(parent.author_id)
      })

      with %Room{} <- place,
           do: broadcast(%RoomActivity{room_id: place.id, community_id: place.community_id})

      played(message)

      {:ok, message}
    end
  end

  @spec list_messages(User.t(), place(), keyword()) ::
          Page.t() | {:error, :forbidden | :not_found | Flop.Meta.t()}
  def list_messages(%User{} = user, place, opts \\ []) when is_list(opts) do
    {parent, paging} = Keyword.pop(opts, :parent)

    case may_read(user, place) do
      :ok ->
        paging
        |> Keyword.merge(where_in(place))
        |> Keyword.put(:reply_to_id, get_in(parent.id))
        |> Keyword.put(:visible_to, viewing(user, place))
        |> Message.paginate()

      error ->
        error
    end
  end

  @spec edit_message(User.t(), Message.t(), map()) ::
          {:ok, Message.t()}
          | {:error,
             :forbidden | :not_found | :too_many_attachments | :invalid_attachment | Changeset.t()}
  def edit_message(%User{}, %Message{kind: :sound}, %{}), do: {:error, :forbidden}

  def edit_message(%User{id: id} = user, %Message{author_id: id} = message, %{} = params) do
    with {:ok, place} <- place_of(message),
         :ok <- may_read(user, place),
         {:ok, message} <- EditMessage.execute(user, message, params) do
      broadcast(%MessageEdited{
        message_id: message.id,
        room_id: message.room_id,
        conversation_id: message.conversation_id
      })

      {:ok, message}
    end
  end

  def edit_message(%User{}, %Message{}, %{}), do: {:error, :forbidden}

  # A message with answers stays as "Message deleted" so the thread keeps its shape
  @spec delete_message(User.t(), Message.t()) ::
          {:ok, Message.t()} | {:error, :forbidden | Changeset.t()}
  def delete_message(%User{id: id}, %Message{author_id: id} = message) do
    result =
      case message.child_count do
        0 -> DeleteMessage.execute(message)
        _answered -> Message.delete(message)
      end

    with {:ok, message} <- result do
      broadcast(%MessageRemoved{
        message_id: message.id,
        room_id: message.room_id,
        conversation_id: message.conversation_id
      })

      {:ok, message}
    end
  end

  def delete_message(%User{}, %Message{}), do: {:error, :forbidden}

  @spec toggle_reaction(User.t(), Message.t(), String.t()) ::
          {:ok, :added | :removed} | {:error, :forbidden | :invalid_emoji}
  def toggle_reaction(%User{} = user, %Message{} = message, emoji) when is_binary(emoji) do
    with :ok <- valid_emoji(emoji),
         {:ok, place} <- place_of(message),
         :ok <- may_read(user, place) do
      state = Reaction.toggle(message.id, user.id, emoji)

      broadcast(%MessageReacted{
        message_id: message.id,
        room_id: message.room_id,
        conversation_id: message.conversation_id,
        user_id: user.id,
        emoji: emoji,
        on: state == :added,
        count: Reaction.count(message.id, emoji)
      })

      {:ok, state}
    end
  end

  # The author takes their own link card off, and in a room a moderator anyone's
  @spec hide_preview(User.t(), Message.t(), boolean()) ::
          {:ok, Message.t()} | {:error, :forbidden | :not_found}
  def hide_preview(%User{id: id}, %Message{author_id: id} = message, hidden?)
      when is_boolean(hidden?),
      do: Message.hide_preview(message, hidden?)

  def hide_preview(%User{} = user, %Message{} = message, hidden?) when is_boolean(hidden?) do
    with {:ok, %Room{} = room} <- place_of(message),
         :ok <- may_read(user, room),
         :all <- viewing(user, room) do
      Message.hide_preview(message, hidden?)
    else
      {:ok, %Conversation{}} -> {:error, :forbidden}
      {:error, _reason} = error -> error
      _not_a_moderator -> {:error, :forbidden}
    end
  end

  @type room_unread :: %{
          room_id: Hearth.Common.T.id(),
          community_id: Hearth.Common.T.id(),
          count: pos_integer()
        }

  @spec unread_counts(User.t()) :: %{
          rooms: [room_unread()],
          conversations: %{Hearth.Common.T.id() => pos_integer()}
        }
  def unread_counts(%User{} = user) do
    joined = IAM.joined_at(user)
    rooms = joined |> Map.keys() |> Communities.list_visible_rooms(:text, user)
    counts = Message.unread_in_rooms(user.id, Map.new(rooms, &{&1.id, joined[&1.community_id]}))

    %{
      rooms:
        for(
          room <- rooms,
          count = counts[room.id],
          do: %{room_id: room.id, community_id: room.community_id, count: count}
        ),
      conversations: Message.unread_in_conversations(user.id)
    }
  end

  @spec list_reactions(User.t(), [Message.t()]) :: %{Hearth.Common.T.id() => [Reaction.summary()]}
  def list_reactions(%User{id: user_id}, messages) when is_list(messages),
    do: messages |> Enum.map(& &1.id) |> Reaction.summaries(user_id)

  @spec start_direct(User.t(), User.t()) ::
          {:ok, Conversation.t()} | {:error, :self | :no_shared_community}
  def start_direct(%User{id: id}, %User{id: id}), do: {:error, :self}

  def start_direct(%User{} = user, %User{} = other) do
    key = [user.id, other.id] |> Enum.sort() |> Enum.join(":")

    with :ok <- share_community(user, [other]) do
      case Conversation.direct(key) do
        nil -> StartConversation.execute(user, [other], kind: :direct, direct_key: key)
        %Conversation{} = conversation -> {:ok, conversation}
      end
    end
  end

  @spec start_group(User.t(), [User.t()], nil | String.t()) ::
          {:ok, Conversation.t()} | {:error, :too_few | :no_shared_community | Changeset.t()}
  def start_group(%User{} = user, others, name \\ nil) when is_list(others) do
    others = Enum.uniq_by(others -- [user], & &1.id)

    with true <- length(others) >= 2,
         :ok <- share_community(user, others) do
      StartConversation.execute(user, others, kind: :group, name: name)
    else
      false -> {:error, :too_few}
      error -> error
    end
  end

  # No checks here since only Hearth.Moderation calls this
  @spec moderate(Message.t(), :published | :pending | :removed) ::
          {:ok, Message.t()} | {:error, Changeset.t()}
  def moderate(%Message{} = message, status), do: Message.put_status(message, status)

  @spec get_message(Hearth.Common.T.id()) :: {:ok, Message.t()} | {:error, :not_found}
  def get_message(id) when is_binary(id) do
    case Message.get(id: id, deleted_at: nil) do
      nil -> {:error, :not_found}
      %Message{} = message -> {:ok, message}
    end
  end

  # Every id must be a message still showing in the room that someone wrote, oldest first
  @spec get_promotable(Room.t(), [Hearth.Common.T.id()]) ::
          {:ok, [Message.t()]} | {:error, :invalid_messages}
  def get_promotable(%Room{id: id}, ids) when is_list(ids) do
    count = ids |> Enum.uniq() |> length()

    case Message.promotable(id, ids) do
      messages when messages != [] and length(messages) == count -> {:ok, messages}
      _missing -> {:error, :invalid_messages}
    end
  end

  # The room's note pointing at the post its messages became
  @spec note_promoted(
          User.t(),
          Room.t(),
          %{:id => Hearth.Common.T.id(), :title => String.t(), optional(atom()) => any()}
        ) ::
          {:ok, Message.t()} | {:error, Changeset.t()}
  def note_promoted(%User{} = user, %Room{} = room, %{id: post_id, title: title}) do
    message = %Message{room_id: room.id, author_id: user.id, kind: :promoted, post_id: post_id}

    with {:ok, message} <- Message.insert(message, %{body: title}) do
      broadcast(%MessageCreated{
        message_id: message.id,
        room_id: room.id,
        conversation_id: nil,
        author_id: user.id,
        reply_to_id: nil,
        reply_to_author_id: nil
      })

      {:ok, message}
    end
  end

  @spec get_conversation(User.t(), Hearth.Common.T.id()) ::
          {:ok, Conversation.t()} | {:error, :not_found}
  def get_conversation(%User{id: user_id}, id) when is_binary(id) do
    with %Conversation{} = conversation <- Conversation.get(id: id, preload: :members),
         true <- ConversationMember.member?(id, user_id) do
      {:ok, conversation}
    else
      _missing -> {:error, :not_found}
    end
  end

  @spec can_read?(User.t(), place()) :: boolean()
  def can_read?(%User{} = user, place), do: may_read(user, place) == :ok

  @spec can_write?(User.t(), place()) :: boolean()
  def can_write?(%User{} = user, place), do: may_write(user, place) == :ok

  # @all reaches everyone only from someone who holds mention.all there, otherwise it is plain text
  @spec mentions_all?(User.t(), Room.t(), String.t()) :: boolean()
  def mentions_all?(%User{} = author, %Room{} = room, body) when is_binary(body) do
    "all" in Common.mentions(body) and
      IAM.can?(author, :all, %{type: :mention, community_id: room.community_id})
  end

  # Authors load in one query and each room once, so a page of messages never asks per message
  @spec mentions_all([Message.t()]) :: MapSet.t(T.id())
  def mentions_all(messages) when is_list(messages) do
    said = Enum.filter(messages, &said_all?/1)
    authors = said |> Enum.map(& &1.author_id) |> Accounts.list_users() |> Map.new(&{&1.id, &1})
    rooms = said |> Enum.map(& &1.room_id) |> Enum.uniq() |> Map.new(&{&1, room(&1)})

    said
    |> Enum.filter(&allowed_all?(&1, authors[&1.author_id], rooms[&1.room_id]))
    |> MapSet.new(& &1.id)
  end

  @spec list_conversations(User.t()) :: [Conversation.t()]
  def list_conversations(%User{id: id}) do
    Conversation.for_member(id)
  end

  @spec mark_read(User.t(), Message.t()) :: :ok | {:error, :forbidden}
  def mark_read(%User{} = user, %Message{} = message) do
    with {:ok, place} <- place_of(message),
         :ok <- may_read(user, place) do
      key =
        case place do
          %Room{id: id} -> {:room, user.id, id}
          %Conversation{id: id} -> {:conversation, user.id, id}
        end

      Buffer.put_newer(ReadMarkers, key, message.id, ReadMarkers.version(message.id))
    end
  end

  # Held messages show to their author, and in a room to whoever can remove content
  defp said_all?(%Message{room_id: room_id, body: body})
       when is_binary(room_id) and is_binary(body),
       do: "all" in Common.mentions(body)

  defp said_all?(%Message{}), do: false

  defp room(id) do
    case Communities.get_room(id: id) do
      {:ok, room} -> room
      {:error, :not_found} -> nil
    end
  end

  defp allowed_all?(%Message{} = message, %User{} = author, %Room{} = room),
    do: mentions_all?(author, room, message.body)

  defp allowed_all?(%Message{}, _author, _room), do: false

  defp viewing(user, %Room{community_id: community_id}) do
    case IAM.can?(user, :remove, %{type: :content, community_id: community_id}) do
      true -> :all
      false -> user.id
    end
  end

  defp viewing(user, %Conversation{}), do: user.id

  defp may_write(user, %Room{} = room) do
    with :ok <- may_read(user, room), do: may_post(user, room)
  end

  defp may_write(user, %Conversation{} = conversation), do: may_read(user, conversation)

  defp may_read(user, %Room{community_id: community_id} = room) do
    case {Communities.room_visible?(user, room), IAM.member?(user, community_id)} do
      {true, _member?} -> :ok
      {false, true} -> {:error, :not_found}
      {false, false} -> Communities.refusal(user, community_id)
    end
  end

  defp may_read(%User{id: user_id}, %Conversation{id: id}) do
    case ConversationMember.member?(id, user_id) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp may_say(_user, _place, kind) when kind in [:text, :action], do: :ok
  defp may_say(_user, %Conversation{}, :sound), do: {:error, :forbidden}

  defp may_say(user, %Room{} = room, :sound) do
    case Communities.can_play?(user, room) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp played(%Message{kind: :sound} = message) do
    broadcast(%SoundPlayed{
      message_id: message.id,
      room_id: message.room_id,
      author_id: message.author_id,
      sound: message.body
    })
  end

  defp played(%Message{}), do: :ok

  defp may_post(user, %Room{archived_at: nil, community_id: community_id}) do
    case IAM.can?(user, :create, %{type: :message, community_id: community_id}) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp may_post(_user, %Room{}), do: {:error, :archived}

  defp where_in(%Room{id: id}), do: [room_id: id]
  defp where_in(%Conversation{id: id}), do: [conversation_id: id]

  defp place_of(%Message{room_id: nil, conversation_id: id}) do
    case Conversation.get(id: id) do
      nil -> {:error, :not_found}
      %Conversation{} = conversation -> {:ok, conversation}
    end
  end

  defp place_of(%Message{room_id: id}), do: Communities.get_room(id: id)

  defp fetch_parent(_place, nil), do: {:ok, nil}

  defp fetch_parent(place, id) do
    case Message.get([id: id, deleted_at: nil] ++ where_in(place)) do
      nil -> {:error, :not_found}
      %Message{status: :pending} -> {:error, :pending}
      %Message{} = parent -> {:ok, parent}
    end
  end

  defp valid_emoji(emoji) do
    case String.length(emoji) in 1..8 and byte_size(emoji) <= 32 do
      true -> :ok
      false -> {:error, :invalid_emoji}
    end
  end

  defp share_community(user, others) do
    case Enum.all?(others, &IAM.share_community?(user, &1)) do
      true -> :ok
      false -> {:error, :no_shared_community}
    end
  end

  defp broadcast(event), do: PubSub.broadcast(@topic, event)
end
