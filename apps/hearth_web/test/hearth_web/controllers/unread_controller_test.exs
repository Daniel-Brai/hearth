defmodule HearthWeb.UnreadControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    room = TestUtils.get_room!(community, type: :text)

    {:ok, binding()}
  end

  describe "show" do
    test "fails signed out", %{conn: conn} do
      conn |> get(~p"/api/unread") |> valid_response(401)
    end

    test "counts unread rooms and conversations", %{
      conn: conn,
      owner: owner,
      member: member,
      room: room
    } do
      {:ok, conversation} = Chat.start_direct(owner, member)
      {:ok, _message} = Chat.send_message(owner, conversation, %{body: Lorem.sentence()})
      {:ok, _message} = Chat.send_message(owner, room, %{body: Lorem.sentence()})
      room_id = room.id
      conversation_id = conversation.id

      assert %{
               "rooms" => [%{"id" => ^room_id, "count" => 1}],
               "conversations" => [%{"id" => ^conversation_id, "count" => 1}]
             } = conn |> auth_conn(member) |> get(~p"/api/unread") |> valid_response(200)
    end
  end
end
