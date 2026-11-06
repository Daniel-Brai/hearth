defmodule HearthWeb.PollControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    room = TestUtils.get_room!(community, type: :text)

    body = %{question: Lorem.sentence(), options: ["Tea", "Coffee"]}

    {:ok, binding()}
  end

  describe "create" do
    test "fails for someone outside the community", %{conn: conn, room: room, body: body} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/rooms/#{room.id}/polls", body)
               |> valid_response(403)
    end

    test "fails with one choice", %{conn: conn, member: member, room: room, body: body} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/polls", %{body | options: ["Tea"]})
               |> valid_response(422)

      assert errors["options"]
    end

    test "fails closing in the past", %{conn: conn, member: member, room: room, body: body} do
      closes_at = -5 |> TestUtils.in_minutes() |> DateTime.to_iso8601()

      assert %{"errors" => %{"closes_at" => [_message]}} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/polls", Map.put(body, :closes_at, closes_at))
               |> valid_response(422)
    end

    test "asks in the room", %{conn: conn, member: member, room: room, body: body} do
      assert %{"kind" => "poll", "body" => question, "poll" => poll} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/rooms/#{room.id}/polls", body)
               |> valid_response(201)

      assert question == body.question
      assert TestUtils.pluck(poll["options"], "label") == body.options
    end
  end

  describe "show" do
    test "fails for someone outside the community", %{conn: conn, owner: owner, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> get(~p"/api/polls/#{poll.id}")
             |> valid_response(403)
    end

    test "shows the totals", %{conn: conn, owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      [option | _options] = poll.options
      {:ok, _view} = Chat.vote(member, poll, [option.id])

      assert %{"voters" => 1, "mine" => []} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/polls/#{poll.id}")
               |> valid_response(200)
    end
  end

  describe "vote" do
    test "fails for two picks in a single choice poll", %{
      conn: conn,
      owner: owner,
      member: member,
      room: room
    } do
      poll = TestUtils.start_random_poll!(owner, room)
      body = %{option_ids: Enum.map(poll.options, & &1.id)}

      assert %{"code" => "invalid_choice"} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/polls/#{poll.id}/vote", body)
               |> valid_response(400)
    end

    test "fails once closed", %{conn: conn, owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      {:ok, _closed} = Chat.close_poll(owner, poll)
      [option | _options] = poll.options

      assert %{"code" => "poll_closed"} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/polls/#{poll.id}/vote", %{option_ids: [option.id]})
               |> valid_response(400)
    end

    test "counts my vote", %{conn: conn, owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)
      [option | _options] = poll.options

      assert %{"voters" => 1, "mine" => [picked]} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/polls/#{poll.id}/vote", %{option_ids: [option.id]})
               |> valid_response(200)

      assert picked == option.id
    end
  end

  describe "update" do
    test "fails for someone else's poll", %{conn: conn, owner: owner, member: member, room: room} do
      poll = TestUtils.start_random_poll!(owner, room)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/polls/#{poll.id}", %{closed: true})
               |> valid_response(403)
    end

    test "closes my poll", %{conn: conn, member: member, room: room} do
      poll = TestUtils.start_random_poll!(member, room)

      assert %{"closed_at" => closed_at} =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/polls/#{poll.id}", %{closed: true})
               |> valid_response(200)

      assert closed_at
    end
  end
end
