defmodule HearthWeb.MessageControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Communities
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)
    room = TestUtils.get_room!(community, type: :text)

    {:ok, binding()}
  end

  describe "room_index" do
    test "fails for someone outside the community", %{conn: conn, room: room} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> get(~p"/api/rooms/#{room.id}/messages")
               |> valid_response(403)
    end

    test "shows each message's reactions", %{conn: conn, owner: owner, member: member, room: room} do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      {:ok, :added} = Chat.toggle_reaction(member, message, "🎉")

      assert %{"data" => [%{"reactions" => [%{"emoji" => "🎉", "count" => 1, "mine" => true}]}]} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/rooms/#{room.id}/messages")
               |> valid_response(200)

      assert %{"data" => [%{"reactions" => [%{"mine" => false}]}]} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/rooms/#{room.id}/messages")
               |> valid_response(200)
    end

    test "lists messages newest first", %{conn: conn, owner: owner, member: member, room: room} do
      {:ok, _older} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      {:ok, newest} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert %{"data" => [latest | _rest]} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/rooms/#{room.id}/messages")
               |> valid_response(200)

      assert latest["id"] == newest.id
    end
  end

  describe "room_create" do
    test "fails due to validation", %{conn: conn, member: member, room: room} do
      body = %{body: ""}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(422)

      assert [_message] = errors["body"]
    end

    test "fails to play if not allowed", %{
      conn: conn,
      member: member,
      community: community,
      room: room
    } do
      TestUtils.put_room_settings!(community, room, %{sounds_mode: :people})
      body = %{body: "tada", kind: "sound"}

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(403)
    end

    test "fails with another kind", %{conn: conn, member: member, room: room} do
      body = %{body: Lorem.sentence(), kind: "promoted"}

      assert %{"errors" => %{"kind" => [_error]}} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(422)
    end

    test "fails with someone else's file", %{conn: conn, owner: owner, member: member, room: room} do
      [theirs] = TestUtils.upload_random_attachments!(owner, 1)
      body = %{body: Lorem.sentence(), attachment_ids: [theirs.id]}

      assert %{"code" => "invalid_attachment"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(400)
    end

    test "leaves @all plain without mention.all", %{conn: conn, member: member, room: room} do
      body = %{body: "Hello @all"}

      assert %{"mentions_all" => false} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(201)
    end

    test "marks @all from someone with mention.all", %{
      conn: conn,
      community: community,
      room: room
    } do
      announcer = TestUtils.join_with_permissions!(community, ~w[message.create mention.all])
      body = %{body: "Hello @all"}

      assert %{"mentions_all" => true} =
               conn
               |> auth_conn(announcer)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(201)
    end

    test "sends files with no text", %{conn: conn, member: member, room: room} do
      [file] = TestUtils.upload_random_attachments!(member, 1)
      body = %{body: "", attachment_ids: [file.id]}

      assert %{"body" => "", "attachments" => [attachment]} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(201)

      assert attachment["id"] == file.id
    end

    test "sends a message", %{conn: conn, member: member, room: room} do
      body = %{body: Lorem.sentence()}

      assert response =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(201)

      assert response["body"] == body.body
      assert response["room_id"] == room.id
    end

    test "sends an action", %{conn: conn, member: member, room: room} do
      body = %{body: Lorem.sentence(), kind: "action"}

      assert response =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(201)

      assert response["kind"] == "action"
    end

    test "plays a sound", %{conn: conn, member: member, room: room} do
      body = %{body: "tada", kind: "sound"}

      assert response =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(201)

      assert response["kind"] == "sound"
    end

    test "answers a message", %{conn: conn, owner: owner, member: member, room: room} do
      {:ok, question} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      body = %{body: Lorem.sentence(), reply_to_id: question.id}

      assert response =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(201)

      assert response["reply_to_id"] == question.id
    end
  end

  describe "conversation_index" do
    test "returns 404 outside conversation", %{
      conn: conn,
      owner: owner,
      member: member
    } do
      {:ok, conversation} = Chat.start_direct(owner, member)

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> get(~p"/api/conversations/#{conversation.id}/messages")
             |> valid_response(404)
    end

    test "lists the conversation's messages", %{conn: conn, owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(owner, member)
      {:ok, message} = Chat.send_message(owner, conversation, %{body: Lorem.sentence()})

      assert %{"data" => [entry]} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/conversations/#{conversation.id}/messages")
               |> valid_response(200)

      assert entry["id"] == message.id
    end
  end

  describe "update" do
    test "fails if not the author", %{conn: conn, owner: owner, member: member, room: room} do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/messages/#{message.id}", %{body: Lorem.sentence()})
               |> valid_response(403)
    end

    test "replaces the files", %{conn: conn, owner: owner, room: room} do
      [original, replacement] = TestUtils.upload_random_attachments!(owner, 2)
      body = %{body: Lorem.sentence(), attachment_ids: [original.id]}
      {:ok, message} = Chat.send_message(owner, room, body)
      changes = %{body: "", attachment_ids: [replacement.id]}

      assert %{"attachments" => [attachment]} =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/messages/#{message.id}", changes)
               |> valid_response(200)

      assert attachment["id"] == replacement.id
    end

    test "edits a message", %{conn: conn, owner: owner, room: room} do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      body = %{body: Lorem.sentence()}

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/messages/#{message.id}", body)
               |> valid_response(200)

      assert response["body"] == body.body
    end
  end

  describe "delete" do
    test "deletes the author's message", %{conn: conn, owner: owner, room: room} do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})

      assert conn |> auth_conn(owner) |> delete(~p"/api/messages/#{message.id}") |> response(204)
    end
  end

  describe "preview" do
    test "fails for someone else's message", %{
      conn: conn,
      owner: owner,
      member: member,
      room: room
    } do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})

      conn
      |> auth_conn(member)
      |> put(~p"/api/messages/#{message.id}/preview", %{hidden: true})
      |> valid_response(403)
    end

    test "takes the link card off", %{conn: conn, member: member, room: room} do
      {:ok, message} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      conn
      |> auth_conn(member)
      |> put(~p"/api/messages/#{message.id}/preview", %{hidden: true})
      |> response(204)

      assert %{"data" => [%{"preview_hidden" => true}]} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/rooms/#{room.id}/messages")
               |> valid_response(200)
    end
  end

  describe "react" do
    test "fails for something that isn't one emoji", %{
      conn: conn,
      owner: owner,
      member: member,
      room: room
    } do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      body = %{emoji: String.duplicate("a", 20)}

      assert %{"code" => "invalid_emoji"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/messages/#{message.id}/reactions", body)
               |> valid_response(400)
    end

    test "adds and takes back a reaction", %{conn: conn, owner: owner, member: member, room: room} do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      body = %{emoji: "🎉"}

      assert %{"on" => true} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/messages/#{message.id}/reactions", body)
               |> valid_response(200)

      assert %{"on" => false} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/messages/#{message.id}/reactions", body)
               |> valid_response(200)
    end
  end

  describe "read" do
    test "records how far the person has read", %{
      conn: conn,
      owner: owner,
      member: member,
      room: room
    } do
      {:ok, message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})

      assert conn
             |> auth_conn(member)
             |> post(~p"/api/messages/#{message.id}/read")
             |> response(204)
    end
  end
end
