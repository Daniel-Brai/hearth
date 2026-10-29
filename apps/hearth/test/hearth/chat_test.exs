defmodule Hearth.ChatTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Accounts
  alias Hearth.Chat
  alias Hearth.Chat.Conversation
  alias Hearth.Chat.ConversationMember
  alias Hearth.Chat.Message
  alias Hearth.Chat.MessageCreated
  alias Hearth.Chat.MessageEdited
  alias Hearth.Chat.MessageReacted
  alias Hearth.Chat.MessageRemoved
  alias Hearth.Chat.RoomActivity
  alias Hearth.Chat.RoomRead
  alias Hearth.Communities
  alias Hearth.Media
  alias Hearth.Repo.Page
  alias Hearth.TestUtils

  setup do
    :ok = Chat.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)

    [room | _rooms] = Communities.list_rooms(community)

    {:ok, binding()}
  end

  describe "send_message/3" do
    test "fails if not a member", %{room: room} do
      assert {:error, :forbidden} =
               Chat.send_message(TestUtils.register_random_user!(), room, %{
                 body: Lorem.sentence()
               })
    end

    test "fails if the room is archived", %{owner: owner, member: member, room: room} do
      {:ok, archived} = Communities.archive_room(owner, room)

      assert {:error, :archived} = Chat.send_message(member, archived, %{body: Lorem.sentence()})
    end

    test "sends to the chat beside a voice room", %{member: member, community: community} do
      voice = TestUtils.get_room!(community, type: :voice)

      assert {:ok, %Message{room_id: room_id}} =
               Chat.send_message(member, voice, %{body: Lorem.sentence()})

      assert room_id == voice.id
    end

    test "fails if answering a message elsewhere", %{
      member: member,
      community: community,
      room: room
    } do
      help = TestUtils.get_room!(community, slug: "help")
      {:ok, message} = Chat.send_message(member, help, %{body: Lorem.sentence()})

      assert {:error, :not_found} =
               Chat.send_message(member, room, %{body: Lorem.sentence(), reply_to_id: message.id})
    end

    test "fails if body is missing", %{member: member, room: room} do
      assert {:error, changeset} = Chat.send_message(member, room, %{body: ""})
      assert %{body: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails with other user's file", %{
      owner: owner,
      member: member,
      room: room
    } do
      [theirs] = TestUtils.upload_random_attachments!(owner, 1)
      body = %{body: Lorem.sentence(), attachment_ids: [theirs.id]}

      assert {:error, :invalid_attachment} = Chat.send_message(member, room, body)
      assert %Page{data: []} = Chat.list_messages(member, room)
    end

    test "sends files with no text", %{member: member, room: room} do
      [file] = TestUtils.upload_random_attachments!(member, 1)
      file_id = file.id

      assert {:ok, %Message{body: ""} = message} =
               Chat.send_message(member, room, %{body: "", attachment_ids: [file.id]})

      assert %{} = attachments = Media.list_attachments(:message, [message.id])
      assert [%{media_id: ^file_id}] = attachments[message.id]
    end

    test "send message", %{member: member, room: room} do
      %{id: author_id} = member
      %{id: room_id} = room

      assert {:ok, %Message{depth: 0, room_id: ^room_id}} =
               Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert_receive %MessageCreated{author_id: ^author_id, reply_to_author_id: nil}
    end

    test "stores a direct message sealed", %{owner: owner, member: member} do
      body = Lorem.sentence()
      {:ok, conversation} = Chat.start_direct(member, owner)
      {:ok, message} = Chat.send_message(member, conversation, %{body: body})

      refute TestUtils.stored_value!(Message, message.id, :body) =~ body
      assert {:ok, %Message{body: ^body}} = Chat.get_message(message.id)
    end

    test "answer a message", %{owner: owner, member: member, room: room} do
      %{id: member_id} = member
      %{id: owner_id} = owner
      {:ok, %{id: id}} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert {:ok, %Message{depth: 1, thread_root_id: ^id}} =
               Chat.send_message(owner, room, %{body: Lorem.sentence(), reply_to_id: id})

      assert {:ok, %Message{child_count: 1, recent_repliers: [^owner_id]}} = Chat.get_message(id)
      assert_receive %MessageCreated{reply_to_author_id: ^member_id}
    end
  end

  describe "list_messages/3" do
    test "fails if not a member", %{room: room} do
      assert {:error, :forbidden} = Chat.list_messages(TestUtils.register_random_user!(), room)
    end

    test "list newest first", %{owner: owner, member: member, room: room} do
      {:ok, %{id: first_id} = first} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, %{id: second_id}} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      {:ok, %{id: answer_id}} =
        Chat.send_message(owner, room, %{body: Lorem.sentence(), reply_to_id: first_id})

      assert %Page{data: [%Message{id: ^second_id}, %Message{id: ^first_id}]} =
               Chat.list_messages(member, room)

      assert %Page{data: [%Message{id: ^answer_id}]} =
               Chat.list_messages(member, room, parent: first)
    end
  end

  describe "edit_message/3" do
    test "replaces the files", %{member: member, room: room} do
      [first, second] = TestUtils.upload_random_attachments!(member, 2)
      body = %{body: Lorem.sentence(), attachment_ids: [first.id]}
      {:ok, message} = Chat.send_message(member, room, body)
      second_id = second.id

      assert {:ok, _edited} =
               Chat.edit_message(member, message, %{body: "", attachment_ids: [second.id]})

      assert [%{media_id: ^second_id}] =
               Media.list_attachments(:message, [message.id])[message.id]
    end

    test "fails if not the author", %{owner: owner, member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert {:error, :forbidden} = Chat.edit_message(owner, message, %{body: Lorem.sentence()})
    end

    test "edits the message", %{member: member, room: room} do
      {:ok, %{id: message_id} = message} =
        Chat.send_message(member, room, %{body: Lorem.sentence()})

      params = %{body: Lorem.sentence()}

      assert {:ok, %Message{edited_at: %DateTime{}} = edited} =
               Chat.edit_message(member, message, params)

      assert edited.body == params.body
      assert_receive %MessageEdited{message_id: ^message_id}
    end
  end

  describe "delete_message/2" do
    test "fails if not the author", %{owner: owner, member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert {:error, :forbidden} = Chat.delete_message(owner, message)
    end

    test "keeps a message that has answers", %{owner: owner, member: member, room: room} do
      {:ok, %{id: id}} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, _answer} = Chat.send_message(owner, room, %{body: Lorem.sentence(), reply_to_id: id})
      {:ok, message} = Chat.get_message(id)

      assert {:ok, %Message{deleted_at: %DateTime{}}} = Chat.delete_message(member, message)
      assert Message.exists?(id: id)
    end

    test "removes a message with no answers", %{owner: owner, member: member, room: room} do
      {:ok, first} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      {:ok, %{id: answer_id} = answer} =
        Chat.send_message(owner, room, %{body: Lorem.sentence(), reply_to_id: first.id})

      assert {:ok, _message} = Chat.delete_message(owner, answer)
      refute Message.exists?(id: answer_id)
      assert {:ok, %Message{child_count: 0, descendant_count: 0}} = Chat.get_message(first.id)
      assert_receive %MessageRemoved{message_id: ^answer_id}
    end
  end

  describe "toggle_reaction/3" do
    test "fails if emoji is too long", %{member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert {:error, :invalid_emoji} =
               Chat.toggle_reaction(member, message, String.duplicate("x", 9))
    end

    test "fails if not a member", %{member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert {:error, :forbidden} =
               Chat.toggle_reaction(TestUtils.register_random_user!(), message, "🔥")
    end

    test "toggle reaction", %{owner: owner, member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      %{id: id} = message

      assert {:ok, :added} = Chat.toggle_reaction(owner, message, "🔥")
      assert_receive %MessageReacted{message_id: ^id, emoji: "🔥", on: true, count: 1}

      assert {:ok, :removed} = Chat.toggle_reaction(owner, message, "🔥")
      assert_receive %MessageReacted{message_id: ^id, emoji: "🔥", on: false, count: 0}
    end
  end

  describe "hide_preview/3" do
    test "fails for someone else's message", %{owner: owner, room: room, community: community} do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      stranger = TestUtils.join_random_member!(community)

      assert {:error, :forbidden} = Chat.hide_preview(stranger, message, true)
    end

    test "hide own preview", %{member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert {:ok, %Message{preview_hidden_at: %DateTime{}}} =
               Chat.hide_preview(member, message, true)
    end

    test "hide any preview as a moderator", %{owner: owner, member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert {:ok, %Message{preview_hidden_at: %DateTime{}}} =
               Chat.hide_preview(owner, message, true)
    end
  end

  describe "unread_counts/1" do
    test "counts others' messages after the read marker", %{
      owner: owner,
      member: member,
      room: room
    } do
      %{id: room_id, community_id: community_id} = room
      {:ok, read} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      :ok = Chat.mark_read(member, read)
      {:ok, _own} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, _new} = Chat.send_message(owner, room, %{body: Lorem.sentence()})

      assert %{rooms: [%{room_id: ^room_id, community_id: ^community_id, count: 1}]} =
               Chat.unread_counts(member)

      assert_receive %RoomActivity{room_id: ^room_id, community_id: ^community_id}
    end

    test "counts from joining if never opened", %{
      owner: owner,
      room: room,
      community: community
    } do
      %{id: room_id} = room
      {:ok, _message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      newcomer = TestUtils.join_random_member!(community)

      assert %{rooms: rooms} = Chat.unread_counts(newcomer)
      refute room_id in TestUtils.pluck(rooms, :room_id)
    end

    test "counts a conversation's unread messages", %{owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(owner, member)
      %{id: conversation_id} = conversation
      {:ok, _message} = Chat.send_message(owner, conversation, %{body: Lorem.sentence()})

      assert %{conversations: %{^conversation_id => 1}} = Chat.unread_counts(member)
      assert %{conversations: conversations} = Chat.unread_counts(owner)
      assert conversations == %{}
    end
  end

  describe "list_reactions/2" do
    test "returns nothing if no reactions", %{member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert %{} == Chat.list_reactions(member, [message])
    end

    test "counts each emoji and marks the viewer's own", %{
      owner: owner,
      member: member,
      room: room
    } do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, :added} = Chat.toggle_reaction(owner, message, "🔥")
      {:ok, :added} = Chat.toggle_reaction(member, message, "🔥")
      {:ok, :added} = Chat.toggle_reaction(owner, message, "👍")
      %{id: id} = message

      assert %{id => [%{emoji: "🔥", count: 2, mine: true}, %{emoji: "👍", count: 1, mine: false}]} ==
               Chat.list_reactions(member, [message])
    end
  end

  describe "start_direct/2" do
    test "fails if talking to oneself", %{member: member} do
      assert {:error, :self} = Chat.start_direct(member, member)
    end

    test "fails if no community is shared", %{member: member} do
      assert {:error, :no_shared_community} =
               Chat.start_direct(member, TestUtils.register_random_user!())
    end

    test "start direct conversation once", %{owner: owner, member: member} do
      assert {:ok, %Conversation{kind: :direct, id: id} = conversation} =
               Chat.start_direct(member, owner)

      assert length(conversation.members) == 2
      assert {:ok, %Conversation{id: ^id}} = Chat.start_direct(owner, member)
    end
  end

  describe "start_group/3" do
    test "fails if too few people", %{owner: owner, member: member} do
      assert {:error, :too_few} = Chat.start_group(member, [owner])
    end

    test "start group", %{owner: owner, member: member, community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)
      name = Lorem.sentence()

      assert {:ok, %Conversation{kind: :group, name: ^name}} =
               Chat.start_group(member, [owner, user], name)

      assert [%Conversation{}] = Chat.list_conversations(user)
    end
  end

  describe "mark_read/2" do
    test "fails if not a member", %{member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      assert {:error, :forbidden} = Chat.mark_read(TestUtils.register_random_user!(), message)
    end

    test "keeps the newest mark in a room", %{owner: owner, member: member, room: room} do
      {:ok, older} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, %{id: id} = newer} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert :ok = Chat.mark_read(owner, newer)
      assert :ok = Chat.mark_read(owner, older)
      assert %RoomRead{last_read_message_id: ^id} = RoomRead.get(user_id: owner.id)
    end

    test "mark read in a conversation", %{owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(member, owner)

      {:ok, %{id: id} = message} =
        Chat.send_message(member, conversation, %{body: Lorem.sentence()})

      assert :ok = Chat.mark_read(owner, message)

      assert %ConversationMember{last_read_message_id: ^id} =
               ConversationMember.get(user_id: owner.id)
    end
  end

  describe "touch_last_seen/1" do
    test "records activity", %{member: member} do
      assert :ok = Accounts.touch_last_seen(member)
      assert {:ok, %{last_seen_at: %DateTime{}}} = Accounts.get_user(id: member.id)
    end
  end
end
