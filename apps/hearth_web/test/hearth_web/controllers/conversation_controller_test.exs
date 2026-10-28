defmodule HearthWeb.ConversationControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Chat
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)

    {:ok, binding()}
  end

  describe "index" do
    test "fails without signing in", %{conn: conn} do
      assert conn |> get(~p"/api/conversations") |> valid_response(401)
    end

    test "lists the person's conversations", %{conn: conn, owner: owner, member: member} do
      {:ok, conversation} = Chat.start_direct(owner, member)

      assert [%{"id" => id, "kind" => "direct", "member_ids" => member_ids}] =
               conn |> auth_conn(member) |> get(~p"/api/conversations") |> valid_response(200)

      assert id == conversation.id
      assert owner.id in member_ids
      assert member.id in member_ids
    end
  end

  describe "create" do
    test "returns 404 if missing", %{conn: conn, owner: owner} do
      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/conversations", %{user_ids: [Common.new_id()]})
             |> valid_response(404)
    end

    test "fails with someone who shares no community", %{conn: conn, owner: owner} do
      body = %{user_ids: [TestUtils.register_random_user!().id]}

      assert %{"code" => "no_shared_community"} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/conversations", body)
               |> valid_response(400)
    end

    test "starts the direct conversation once", %{conn: conn, owner: owner, member: member} do
      body = %{user_ids: [member.id]}

      assert %{"kind" => "direct", "id" => id} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/conversations", body)
               |> valid_response(201)

      assert %{"id" => ^id} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/conversations", body)
               |> valid_response(201)
    end
  end
end
