defmodule HearthWeb.RoomControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.IAM.Role
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)

    {:ok, binding()}
  end

  describe "create" do
    test "fails due to validation", %{conn: conn, owner: owner, community: community} do
      body = %{name: ""}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/rooms", body)
               |> valid_response(422)

      assert "The name field is required." in errors["name"]
    end

    test "fails for a member without the permission", %{conn: conn, community: community} do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/communities/#{community.id}/rooms", %{name: Lorem.word()})
               |> valid_response(403)
    end

    test "adds a room", %{conn: conn, owner: owner, community: community} do
      body = %{name: Lorem.word()}

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/rooms", body)
               |> valid_response(201)

      assert response["name"] == body.name
    end

    test "adds a private room", %{conn: conn, owner: owner, community: community} do
      moderator = Role.get(community_id: community.id, key: "moderator")
      body = %{name: Lorem.word(), access: "roles", role_ids: [moderator.id]}

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/rooms", body)
               |> valid_response(201)

      assert response["access"] == "roles"
      assert response["role_ids"] == [moderator.id]
    end
  end

  describe "update" do
    test "fails for a private room the member can't see", %{conn: conn, community: community} do
      member = TestUtils.join_random_member!(community)
      room = TestUtils.create_random_private_room!(community, ["moderator"])

      assert %{"code" => "not_found"} =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/rooms/#{room.id}", %{name: Lorem.word()})
               |> valid_response(404)
    end

    test "opens a private room to everyone", %{conn: conn, owner: owner, community: community} do
      room = TestUtils.create_random_private_room!(community, ["moderator"])
      body = %{access: "everyone"}

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/rooms/#{room.id}", body)
               |> valid_response(200)

      assert response["access"] == "everyone"
    end

    test "fails with an unknown sound mode", %{conn: conn, owner: owner, community: community} do
      room = TestUtils.get_room!(community, type: :text)
      body = %{settings: %{sounds_mode: "nobody"}}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/rooms/#{room.id}", body)
               |> valid_response(422)

      assert [_error] = errors["settings.sounds_mode"]
    end

    test "changes the settings", %{conn: conn, owner: owner, community: community} do
      room = TestUtils.get_room!(community, type: :text)

      body = %{
        settings: %{link_previews: false, sounds_mode: "people", sounds_user_ids: [owner.id]}
      }

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/rooms/#{room.id}", body)
               |> valid_response(200)

      assert response["settings"]["sounds_mode"] == "people"
      assert response["settings"]["sounds_user_ids"] == [owner.id]
      assert response["settings"]["sounds_enabled"]
    end

    test "changes a room", %{conn: conn, owner: owner, community: community} do
      {:ok, room} = Communities.create_room(owner, community, %{name: Lorem.word()})
      body = %{topic: Lorem.sentence()}

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/rooms/#{room.id}", body)
               |> valid_response(200)

      assert response["topic"] == body.topic
    end
  end

  describe "archived" do
    test "fails for a member without the permission", %{conn: conn, community: community} do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/communities/#{community.id}/rooms/archived")
               |> valid_response(403)
    end

    test "lists archived rooms", %{conn: conn, owner: owner, community: community} do
      {:ok, room} = Communities.create_room(owner, community, %{name: Lorem.word()})
      {:ok, _room} = Communities.archive_room(owner, room)

      assert [%{"id" => id}] =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/communities/#{community.id}/rooms/archived")
               |> valid_response(200)

      assert id == room.id
    end
  end

  describe "archive" do
    test "archives a room", %{conn: conn, owner: owner, community: community} do
      {:ok, room} = Communities.create_room(owner, community, %{name: Lorem.word()})

      assert %{"archived_at" => archived_at} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/rooms/#{room.id}/archive")
               |> valid_response(200)

      assert archived_at

      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/rooms/#{room.id}/archive")
             |> valid_response(404)
    end
  end

  describe "restore" do
    test "restores a room", %{conn: conn, owner: owner, community: community} do
      {:ok, room} = Communities.create_room(owner, community, %{name: Lorem.word()})
      {:ok, _room} = Communities.archive_room(owner, room)

      assert %{"archived_at" => nil} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/rooms/#{room.id}/restore")
               |> valid_response(200)
    end
  end

  describe "delete" do
    test "fails for a moderator", %{conn: conn, owner: owner, community: community} do
      moderator = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(moderator, community.id, ["moderator"])
      {:ok, room} = Communities.create_room(owner, community, %{name: Lorem.word()})

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(moderator)
               |> delete(~p"/api/rooms/#{room.id}")
               |> valid_response(403)
    end

    test "deletes a room", %{conn: conn, owner: owner, community: community} do
      {:ok, room} = Communities.create_room(owner, community, %{name: Lorem.word()})

      assert conn |> auth_conn(owner) |> delete(~p"/api/rooms/#{room.id}") |> response(204)
      assert conn |> auth_conn(owner) |> delete(~p"/api/rooms/#{room.id}") |> valid_response(404)
    end
  end

  describe "create_group" do
    test "fails due to validation", %{conn: conn, owner: owner, community: community} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/room-groups", %{name: ""})
               |> valid_response(422)

      assert "The name field is required." in errors["name"]
    end

    test "fails for a member", %{conn: conn, community: community} do
      member = TestUtils.join_random_member!(community)

      assert conn
             |> auth_conn(member)
             |> post(~p"/api/communities/#{community.id}/room-groups", %{name: Lorem.word()})
             |> valid_response(403)
    end

    test "adds a group", %{conn: conn, owner: owner, community: community} do
      body = %{name: Lorem.word()}

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/room-groups", body)
               |> valid_response(201)

      assert response["name"] == body.name
    end
  end

  describe "update_group" do
    test "returns 404 for a group that doesn't exist", %{conn: conn, owner: owner} do
      assert conn
             |> auth_conn(owner)
             |> patch(~p"/api/room-groups/#{Common.new_id()}", %{name: Lorem.word()})
             |> valid_response(404)
    end

    test "renames a group", %{conn: conn, owner: owner, community: community} do
      group = TestUtils.create_random_room_group!(community)
      body = %{name: Lorem.word()}

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/room-groups/#{group.id}", body)
               |> valid_response(200)

      assert response["name"] == body.name
    end
  end

  describe "delete_group" do
    test "fails for a member", %{conn: conn, community: community} do
      member = TestUtils.join_random_member!(community)
      group = TestUtils.create_random_room_group!(community)

      assert conn
             |> auth_conn(member)
             |> delete(~p"/api/room-groups/#{group.id}")
             |> valid_response(403)
    end

    test "deletes a group", %{conn: conn, owner: owner, community: community} do
      group = TestUtils.create_random_room_group!(community)

      assert conn |> auth_conn(owner) |> delete(~p"/api/room-groups/#{group.id}") |> response(204)
    end
  end

  describe "arrange" do
    test "fails if a room is left out", %{conn: conn, owner: owner, community: community} do
      body = %{groups: [], room_ids: []}

      assert %{"code" => "layout_mismatch"} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/room-layout", body)
               |> valid_response(400)
    end

    test "puts rooms into groups", %{conn: conn, owner: owner, community: community} do
      group = TestUtils.create_random_room_group!(community)
      general = TestUtils.get_room!(community, slug: "general")
      body = %{groups: [%{id: group.id, room_ids: [general.id]}], room_ids: []}

      assert conn
             |> auth_conn(owner)
             |> put(~p"/api/communities/#{community.id}/room-layout", body)
             |> response(204)

      assert %{"community" => %{"room_groups" => [%{"id" => group_id}]}} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/communities/#{community.id}")
               |> valid_response(200)

      assert group_id == group.id
    end
  end
end
