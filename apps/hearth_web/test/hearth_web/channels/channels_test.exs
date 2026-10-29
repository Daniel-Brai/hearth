defmodule HearthWeb.ChannelsTest do
  use HearthWeb.ChannelCase, async: false

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.TestUtils
  alias HearthWeb.Presence

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    {:ok, [kind | _kinds]} = Forum.create_default_kinds(community.id, community.template)
    room = TestUtils.get_room!(community, type: :text)
    outsider = TestUtils.register_random_user!()

    {:ok, binding()}
  end

  describe "user:<id>" do
    test "fails for someone else", %{owner: owner, outsider: outsider} do
      assert {:error, %{reason: "unauthorized"}} =
               outsider |> connected_socket() |> subscribe_and_join("user:#{owner.id}")
    end

    test "joins one's own and shows as online", %{owner: owner} do
      assert {:ok, _reply, socket} =
               owner |> connected_socket() |> subscribe_and_join("user:#{owner.id}")

      _state = :sys.get_state(socket.channel_pid)

      assert owner.id in Presence.online_ids()

      # Closing writes last seen, so the channel goes before the test's database does
      true = Process.unlink(socket.channel_pid)
      :ok = close(socket)
    end
  end

  describe "community:<id>" do
    test "fails if private", %{
      owner: owner,
      outsider: outsider
    } do
      private = TestUtils.create_random_community!(owner, visibility: :private)

      assert {:error, %{reason: "unauthorized"}} =
               outsider |> connected_socket() |> subscribe_and_join("community:#{private.id}")
    end

    test "fails for a topic that isn't an id", %{owner: owner} do
      assert {:error, %{reason: "unauthorized"}} =
               owner |> connected_socket() |> subscribe_and_join("community:nope")
    end

    test "pushes new posts", %{owner: owner, community: community, kind: kind} do
      topic = "community:#{community.id}"
      {:ok, _reply, _socket} = owner |> connected_socket() |> subscribe_and_join(topic)

      post = TestUtils.create_random_post!(owner, community, kind_id: kind.id)

      assert_push "PostCreated", %{post_id: post_id}
      assert post_id == post.id
    end
  end

  describe "room:<id>" do
    test "fails for someone outside the community", %{room: room, outsider: outsider} do
      assert {:error, %{reason: "unauthorized"}} =
               outsider |> connected_socket() |> subscribe_and_join("room:#{room.id}")
    end

    test "pushes new messages", %{owner: owner, room: room} do
      topic = "room:#{room.id}"
      {:ok, _reply, _socket} = owner |> connected_socket() |> subscribe_and_join(topic)

      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})

      assert_push "MessageCreated", %{message_id: message_id}
      assert message_id == message.id
    end
  end

  describe "conversation:<id>" do
    test "fails for someone outside the conversation", %{
      owner: owner,
      community: community,
      outsider: outsider
    } do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)
      {:ok, conversation} = Chat.start_direct(owner, member)

      assert {:error, %{reason: "unauthorized"}} =
               outsider
               |> connected_socket()
               |> subscribe_and_join("conversation:#{conversation.id}")
    end
  end

  describe "typing" do
    test "fails for an event the channel doesn't know", %{owner: owner, room: room} do
      topic = "room:#{room.id}"
      {:ok, _reply, socket} = owner |> connected_socket() |> subscribe_and_join(topic)

      ref = push(socket, "typed", %{"typing" => true})

      assert_reply ref, :error, %{reason: "unknown"}
    end

    test "drops it in a room nobody can post in", %{owner: owner, room: room} do
      {:ok, archived} = Communities.archive_room(owner, room)
      topic = "room:#{archived.id}"
      {:ok, _reply, socket} = owner |> connected_socket() |> subscribe_and_join(topic)

      push(socket, "typing", %{"typing" => true})

      refute_broadcast "typing", _payload, 200
    end

    test "tells the room someone is typing", %{owner: owner, room: room} do
      %{id: owner_id} = owner
      topic = "room:#{room.id}"
      {:ok, _reply, socket} = owner |> connected_socket() |> subscribe_and_join(topic)

      push(socket, "typing", %{"typing" => true})

      assert_broadcast "typing", %{user_id: ^owner_id, typing: true}
    end

    test "tells the conversation someone stopped", %{owner: owner, community: community} do
      %{id: owner_id} = owner
      member = TestUtils.join_random_member!(community)
      {:ok, conversation} = Chat.start_direct(owner, member)
      topic = "conversation:#{conversation.id}"
      {:ok, _reply, socket} = owner |> connected_socket() |> subscribe_and_join(topic)

      push(socket, "typing", %{"typing" => false})

      assert_broadcast "typing", %{user_id: ^owner_id, typing: false}
    end
  end

  describe "post:<id>" do
    test "pushes new replies", %{owner: owner, community: community, kind: kind} do
      post = TestUtils.create_random_post!(owner, community, kind_id: kind.id)

      topic = "post:#{post.id}"
      {:ok, _reply, _socket} = owner |> connected_socket() |> subscribe_and_join(topic)

      {:ok, reply} = Forum.reply(owner, post, %{body: Lorem.sentence()})

      assert_push "ReplyCreated", %{reply_id: reply_id}
      assert reply_id == reply.id
    end
  end
end
