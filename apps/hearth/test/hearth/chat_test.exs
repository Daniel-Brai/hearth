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
  alias Hearth.Chat.SoundPlayed
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

    test "fails in a private room they can't see", %{member: member, community: community} do
      room = TestUtils.create_random_private_room!(community, ["moderator"])

      assert {:error, :not_found} = Chat.send_message(member, room, %{body: Lorem.sentence()})
    end

    test "fails if the room is archived", %{owner: owner, member: member, room: room} do
      {:ok, archived} = Communities.archive_room(owner, room)

      assert {:error, :archived} = Chat.send_message(member, archived, %{body: Lorem.sentence()})
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

    test "sends to the chat beside a voice room", %{member: member, community: community} do
      voice = TestUtils.get_room!(community, type: :voice)

      assert {:ok, %Message{room_id: room_id}} =
               Chat.send_message(member, voice, %{body: Lorem.sentence()})

      assert room_id == voice.id
    end

    test "sends files with no text", %{member: member, room: room} do
      [file] = TestUtils.upload_random_attachments!(member, 1)
      params = %{body: "", attachment_ids: [file.id]}

      assert {:ok, %Message{body: ""} = message} = Chat.send_message(member, room, params)
      assert [attachment] = Media.list_attachments(:message, [message.id])[message.id]
      assert attachment.media_id == file.id
    end

    test "fails to play a sound in a direct message", %{owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(member, owner)

      assert {:error, :forbidden} =
               Chat.send_message(member, conversation, %{body: "tada", kind: :sound})
    end

    test "fails to play a sound that isn't one", %{member: member, room: room} do
      assert {:error, changeset} = Chat.send_message(member, room, %{body: "x", kind: :sound})
      assert %{body: ["is invalid"]} = errors_on(changeset)
    end

    test "fails to play when sounds are off", %{owner: owner, community: community, room: room} do
      room = TestUtils.put_room_settings!(community, room, %{sounds_enabled: false})

      assert {:error, :forbidden} = Chat.send_message(owner, room, %{body: "tada", kind: :sound})
    end

    test "fails to play if not picked", %{member: member, community: community, room: room} do
      room = TestUtils.put_room_settings!(community, room, %{sounds_mode: :people})

      assert {:error, :forbidden} = Chat.send_message(member, room, %{body: "tada", kind: :sound})
    end

    test "fails to send an action with files", %{member: member, room: room} do
      [file] = TestUtils.upload_random_attachments!(member, 1)
      params = %{body: Lorem.sentence(), kind: :action, attachment_ids: [file.id]}

      assert {:error, changeset} = Chat.send_message(member, room, params)
      assert %{attachment_ids: [_error]} = errors_on(changeset)
    end

    test "sends an action", %{member: member, room: room} do
      params = %{body: Lorem.sentence(), kind: :action}

      assert {:ok, %Message{kind: :action}} = Chat.send_message(member, room, params)
      assert_receive %MessageCreated{}
      refute_receive %SoundPlayed{}
    end

    test "plays a sound", %{member: member, room: room} do
      %{id: room_id} = room

      assert {:ok, %Message{kind: :sound} = message} =
               Chat.send_message(member, room, %{body: "tada", kind: :sound})

      assert_receive %SoundPlayed{room_id: ^room_id, sound: "tada"} = event
      assert event.message_id == message.id
    end

    test "plays a sound in a voice room's chat", %{member: member, community: community} do
      voice = TestUtils.get_room!(community, type: :voice)

      assert {:ok, %Message{kind: :sound}} =
               Chat.send_message(member, voice, %{body: "horn", kind: :sound})
    end

    test "plays a sound for a picked role", %{member: member, community: community, room: room} do
      role_id = TestUtils.get_role_id!(community, "member")
      settings = %{sounds_mode: :roles, sounds_role_ids: [role_id]}
      room = TestUtils.put_room_settings!(community, room, settings)

      assert {:ok, %Message{kind: :sound}} =
               Chat.send_message(member, room, %{body: "tada", kind: :sound})
    end

    test "send message", %{member: member, room: room} do
      %{id: author_id} = member
      params = %{body: Lorem.sentence()}

      assert {:ok, %Message{depth: 0} = message} = Chat.send_message(member, room, params)
      assert message.room_id == room.id
      assert_receive %MessageCreated{author_id: ^author_id, reply_to_author_id: nil}
    end

    test "stores a direct message sealed", %{owner: owner, member: member} do
      body = Lorem.sentence()
      {:ok, conversation} = Chat.start_direct(member, owner)
      {:ok, message} = Chat.send_message(member, conversation, %{body: body})

      refute TestUtils.stored_value!(Message, message.id, :body) =~ body
      assert {:ok, stored} = Chat.get_message(message.id)
      assert stored.body == body
    end

    test "answer a message", %{owner: owner, member: member, room: room} do
      %{id: member_id} = member
      {:ok, question} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      %{id: question_id} = question
      params = %{body: Lorem.sentence(), reply_to_id: question.id}

      assert {:ok, %Message{depth: 1} = answer} = Chat.send_message(owner, room, params)
      assert answer.thread_root_id == question.id
      assert {:ok, %Message{child_count: 1} = question} = Chat.get_message(question.id)
      assert question.recent_repliers == [owner.id]
      assert_receive %MessageCreated{reply_to_id: ^question_id, reply_to_author_id: ^member_id}
    end
  end

  describe "list_messages/3" do
    test "fails if not a member", %{room: room} do
      assert {:error, :forbidden} = Chat.list_messages(TestUtils.register_random_user!(), room)
    end

    test "fails in a private room they can't see", %{member: member, community: community} do
      room = TestUtils.create_random_private_room!(community, ["moderator"])

      assert {:error, :not_found} = Chat.list_messages(member, room)
    end

    test "list in a private room they can see", %{member: member, community: community} do
      room = TestUtils.create_random_private_room!(community, ["member"])

      assert %Page{data: []} = Chat.list_messages(member, room)
    end

    test "list newest first", %{owner: owner, member: member, room: room} do
      {:ok, older} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, newer} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      params = %{body: Lorem.sentence(), reply_to_id: older.id}
      {:ok, answer} = Chat.send_message(owner, room, params)

      assert %Page{data: [newest | _rest]} = Chat.list_messages(member, room)
      assert newest.id == newer.id
      assert %Page{data: [reply]} = Chat.list_messages(member, room, parent: older)
      assert reply.id == answer.id
    end
  end

  describe "edit_message/3" do
    test "fails if not the author", %{owner: owner, member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert {:error, :forbidden} = Chat.edit_message(owner, message, %{body: Lorem.sentence()})
    end

    test "fails once they can't see the room", %{
      owner: owner,
      member: member,
      community: community
    } do
      room = TestUtils.create_random_private_room!(community, ["moderator"])
      {:ok, _membership} = Communities.set_member_roles(owner, community, member, ["moderator"])
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, _membership} = Communities.set_member_roles(owner, community, member, ["member"])

      assert {:error, :not_found} = Chat.edit_message(member, message, %{body: Lorem.sentence()})
    end

    test "fails on a sound", %{member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: "tada", kind: :sound})

      assert {:error, :forbidden} = Chat.edit_message(member, message, %{body: "horn"})
    end

    test "replaces the files", %{member: member, room: room} do
      [first, second] = TestUtils.upload_random_attachments!(member, 2)
      body = %{body: Lorem.sentence(), attachment_ids: [first.id]}
      {:ok, message} = Chat.send_message(member, room, body)
      params = %{body: "", attachment_ids: [second.id]}

      assert {:ok, _edited} = Chat.edit_message(member, message, params)
      assert [attachment] = Media.list_attachments(:message, [message.id])[message.id]
      assert attachment.media_id == second.id
    end

    test "edits the message", %{member: member, room: room} do
      sent = %{body: Lorem.sentence()}
      {:ok, %{id: message_id} = message} = Chat.send_message(member, room, sent)
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
      {:ok, question} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      params = %{body: Lorem.sentence(), reply_to_id: question.id}
      {:ok, _answer} = Chat.send_message(owner, room, params)
      {:ok, answered} = Chat.get_message(question.id)

      assert {:ok, %Message{deleted_at: %DateTime{}}} = Chat.delete_message(member, answered)
      assert Message.exists?(id: question.id)
    end

    test "removes a message with no answers", %{owner: owner, member: member, room: room} do
      {:ok, question} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      params = %{body: Lorem.sentence(), reply_to_id: question.id}
      {:ok, %{id: answer_id} = answer} = Chat.send_message(owner, room, params)

      assert {:ok, _message} = Chat.delete_message(owner, answer)
      refute Message.exists?(id: answer.id)
      assert {:ok, %Message{child_count: 0, descendant_count: 0}} = Chat.get_message(question.id)
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

    test "fails in a private room they can't see", %{
      owner: owner,
      member: member,
      community: community
    } do
      room = TestUtils.create_random_private_room!(community, ["moderator"])
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})

      assert {:error, :not_found} = Chat.toggle_reaction(member, message, "🔥")
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

      assert %{rooms: [unread]} = Chat.unread_counts(member)
      assert unread == %{room_id: room.id, community_id: room.community_id, count: 1}
      assert_receive %RoomActivity{room_id: ^room_id, community_id: ^community_id}
    end

    test "counts from joining if never opened", %{
      owner: owner,
      room: room,
      community: community
    } do
      {:ok, _message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      newcomer = TestUtils.join_random_member!(community)

      assert %{rooms: rooms} = Chat.unread_counts(newcomer)
      refute room.id in TestUtils.pluck(rooms, :room_id)
    end

    test "leaves out private rooms they can't see", %{
      owner: owner,
      member: member,
      community: community
    } do
      hidden = TestUtils.create_random_private_room!(community, ["moderator"])
      shown = TestUtils.create_random_private_room!(community, ["member"])
      {:ok, _message} = Chat.send_message(owner, hidden, %{body: Lorem.sentence()})
      {:ok, _message} = Chat.send_message(owner, shown, %{body: Lorem.sentence()})

      assert %{rooms: [unread]} = Chat.unread_counts(member)
      assert unread.room_id == shown.id
    end

    test "counts a conversation's unread messages", %{owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(owner, member)
      {:ok, _message} = Chat.send_message(owner, conversation, %{body: Lorem.sentence()})

      assert %{conversations: unread} = Chat.unread_counts(member)
      assert unread == %{conversation.id => 1}
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

      assert %{
               message.id => [
                 %{emoji: "🔥", count: 2, mine: true},
                 %{emoji: "👍", count: 1, mine: false}
               ]
             } ==
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
      assert {:ok, %Conversation{kind: :direct} = started} = Chat.start_direct(member, owner)
      assert {:ok, again} = Chat.start_direct(owner, member)
      assert again.id == started.id
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

      assert {:ok, %Conversation{kind: :group} = group} =
               Chat.start_group(member, [owner, user], name)

      assert group.name == name
      assert [%Conversation{}] = Chat.list_conversations(user)
    end
  end

  describe "mentions_all?/3" do
    test "returns false without mention.all", %{member: member, room: room} do
      refute Chat.mentions_all?(member, room, "Hello @all")
    end

    test "returns false without @all", %{owner: owner, room: room} do
      refute Chat.mentions_all?(owner, room, "Hello everyone")
    end

    test "returns true for someone with mention.all", %{community: community, room: room} do
      announcer = TestUtils.join_with_permissions!(community, ~w[message.create mention.all])

      assert Chat.mentions_all?(announcer, room, "Hello @all")
    end
  end

  describe "can_write?/2" do
    test "returns false in an archived room", %{owner: owner, member: member, room: room} do
      {:ok, archived} = Communities.archive_room(owner, room)

      refute Chat.can_write?(member, archived)
    end

    test "returns true for a member in an open room", %{member: member, room: room} do
      assert Chat.can_write?(member, room)
    end
  end

  describe "mark_read/2" do
    test "fails if not a member", %{member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      assert {:error, :forbidden} = Chat.mark_read(TestUtils.register_random_user!(), message)
    end

    test "keeps the newest mark in a room", %{owner: owner, member: member, room: room} do
      {:ok, older} = Chat.send_message(member, room, %{body: Lorem.sentence()})
      {:ok, newer} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert :ok = Chat.mark_read(owner, newer)
      assert :ok = Chat.mark_read(owner, older)
      assert %RoomRead{} = read = RoomRead.get(user_id: owner.id)
      assert read.last_read_message_id == newer.id
    end

    test "mark read in a conversation", %{owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(member, owner)

      params = %{body: Lorem.sentence()}
      {:ok, message} = Chat.send_message(member, conversation, params)

      assert :ok = Chat.mark_read(owner, message)
      assert %ConversationMember{} = read = ConversationMember.get(user_id: owner.id)
      assert read.last_read_message_id == message.id
    end
  end

  describe "touch_last_seen/1" do
    test "records activity", %{member: member} do
      assert :ok = Accounts.touch_last_seen(member)
      assert {:ok, %{last_seen_at: %DateTime{}}} = Accounts.get_user(id: member.id)
    end
  end
end
