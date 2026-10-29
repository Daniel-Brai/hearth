defmodule HearthWeb.CommunityMemberControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Communities
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!(username: "owl_owner")
    community = TestUtils.create_random_community!(owner)

    {:ok, binding()}
  end

  describe "index" do
    test "returns 404 if private", %{conn: conn, owner: owner} do
      private = TestUtils.create_random_community!(owner, visibility: :private)

      assert conn |> get(~p"/api/communities/#{private.id}/members?q=owl") |> valid_response(404)
    end

    test "returns 404 if invite only", %{
      conn: conn,
      owner: owner
    } do
      community = TestUtils.create_random_community!(owner, visibility: :invite_only)

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> get(~p"/api/communities/#{community.id}/members?q=owl")
             |> valid_response(404)
    end

    test "finds members with roles", %{conn: conn, owner: owner, community: community} do
      member = TestUtils.register_random_user!(username: "owl_member")
      {:ok, _membership} = Communities.join(member, community)
      _outsider = TestUtils.register_random_user!(username: "owl_outsider")

      assert response =
               conn
               |> get(~p"/api/communities/#{community.id}/members?q=owl")
               |> valid_response(200)

      assert response |> TestUtils.pluck("user") |> TestUtils.pluck("id") == [member.id, owner.id]
      assert [%{"role_keys" => ["member"]} | _rest] = response
    end
  end
end
