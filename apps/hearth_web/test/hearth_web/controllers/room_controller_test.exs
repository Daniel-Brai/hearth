defmodule HearthWeb.RoomControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Communities
  alias Hearth.IAM
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
  end

  describe "update" do
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
end
