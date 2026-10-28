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
      {:ok, first} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      {:ok, second} = Chat.send_message(member, room, %{body: Lorem.sentence()})

      assert %{"data" => [newest, oldest]} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/rooms/#{room.id}/messages")
               |> valid_response(200)

      assert newest["id"] == second.id
      assert oldest["id"] == first.id
      assert oldest["author"]["id"] == owner.id
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

    test "fails with someone else's file", %{conn: conn, owner: owner, member: member, room: room} do
      [theirs] = TestUtils.upload_random_attachments!(owner, 1)
      body = %{body: Lorem.sentence(), attachment_ids: [theirs.id]}

      assert %{"code" => "invalid_attachment"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(400)
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
      assert attachment["urls"]["original"]
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

    test "answers a message", %{conn: conn, owner: owner, member: member, room: room} do
      {:ok, question} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      body = %{body: Lorem.sentence(), reply_to_id: question.id}

      assert response =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/messages", body)
               |> valid_response(201)

      assert response["reply_to_id"] == question.id
      assert response["depth"] == 1
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
      assert entry["body"] == message.body
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
      [first, second] = TestUtils.upload_random_attachments!(owner, 2)
      body = %{body: Lorem.sentence(), attachment_ids: [first.id]}
      {:ok, message} = Chat.send_message(owner, room, body)

      assert %{"attachments" => [attachment]} =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/messages/#{message.id}", %{body: "", attachment_ids: [second.id]})
               |> valid_response(200)

      assert attachment["id"] == second.id
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
