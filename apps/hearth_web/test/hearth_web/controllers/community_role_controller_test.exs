defmodule HearthWeb.CommunityRoleControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.TestUtils

  setup do
    {:ok, owner: TestUtils.register_random_user!()}
  end

  describe "index" do
    test "returns 404 if private", %{conn: conn, owner: owner} do
      private = TestUtils.create_random_community!(owner, visibility: :private)

      assert conn |> get(~p"/api/communities/#{private.id}/roles") |> valid_response(404)
    end

    test "returns 404 if invite only", %{
      conn: conn,
      owner: owner
    } do
      community = TestUtils.create_random_community!(owner, visibility: :invite_only)

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> get(~p"/api/communities/#{community.id}/roles")
             |> valid_response(404)
    end

    test "lists the roles in order", %{conn: conn, owner: owner} do
      community = TestUtils.create_random_community!(owner)

      assert response =
               conn |> get(~p"/api/communities/#{community.id}/roles") |> valid_response(200)

      assert TestUtils.pluck(response, "key") == ~w[owner moderator member]
    end
  end

  describe "create" do
    setup %{owner: owner}, do: {:ok, community: TestUtils.create_random_community!(owner)}

    test "fails if not allowed to change roles", %{conn: conn, community: community} do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/communities/#{community.id}/roles", %{
                 key: "helper",
                 name: "Helper"
               })
               |> valid_response(403)
    end

    test "fails for a permission that doesn't exist", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      body = %{key: "helper", name: "Helper", permissions: ["nothing.real"]}

      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/communities/#{community.id}/roles", body)
             |> valid_response(422)
    end

    test "adds the role", %{conn: conn, owner: owner, community: community} do
      body = %{key: "helper", name: "Helper", permissions: ["post.pin"]}

      assert %{"key" => "helper", "name" => "Helper", "permissions" => ["post.pin"]} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/roles", body)
               |> valid_response(201)
    end
  end

  describe "update" do
    setup %{owner: owner} do
      community = TestUtils.create_random_community!(owner)
      {:ok, community: community, roles: IAM.list_roles(community.id)}
    end

    test "fails for the Owner role", %{conn: conn, owner: owner, roles: [owner_role | _]} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/roles/#{owner_role.id}", %{name: "Boss"})
               |> valid_response(403)
    end

    test "changes the role", %{conn: conn, owner: owner, roles: [_owner, moderator, _member]} do
      assert %{"name" => "Keeper"} =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/roles/#{moderator.id}", %{name: "Keeper"})
               |> valid_response(200)
    end
  end

  describe "delete" do
    setup %{owner: owner}, do: {:ok, community: TestUtils.create_random_community!(owner)}

    test "fails for the Owner role", %{conn: conn, owner: owner, community: community} do
      [owner_role | _] = IAM.list_roles(community.id)

      assert %{"code" => "system_role"} =
               conn
               |> auth_conn(owner)
               |> delete(~p"/api/roles/#{owner_role.id}")
               |> valid_response(400)
    end

    test "deletes the role", %{conn: conn, owner: owner, community: community} do
      changes = %{key: "helper", name: "Helper"}
      {:ok, role} = Communities.create_role(owner, community, changes)

      assert conn
             |> auth_conn(owner)
             |> delete(~p"/api/roles/#{role.id}")
             |> response(204)

      assert {:error, :not_found} = IAM.get_role(role.id)
    end
  end

  describe "member_roles" do
    setup %{owner: owner} do
      community = TestUtils.create_random_community!(owner)
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      {:ok, community: community, member: member}
    end

    test "fails when making someone Owner", %{
      conn: conn,
      owner: owner,
      community: community,
      member: member
    } do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/members/#{member.id}/roles", %{
                 keys: ["owner"]
               })
               |> valid_response(403)
    end

    test "sets the member's roles", %{
      conn: conn,
      owner: owner,
      community: community,
      member: member
    } do
      user_id = member.id

      assert %{"user_id" => ^user_id, "keys" => ["moderator"]} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/members/#{member.id}/roles", %{
                 keys: ["moderator"]
               })
               |> valid_response(200)
    end
  end
end
