defmodule HearthWeb.CommunityKindControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Forum
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)

    {:ok, binding()}
  end

  describe "update" do
    test "returns 401 without signing in", %{conn: conn, community: community} do
      body = %{kinds: TestUtils.kinds_input(community)}

      assert conn |> put(~p"/api/communities/#{community.id}/kinds", body) |> valid_response(401)
    end

    test "returns 404 for an outsider to a private community", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      private = TestUtils.create_random_community!(owner, visibility: :private)
      body = %{kinds: TestUtils.kinds_input(community)}

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> put(~p"/api/communities/#{private.id}/kinds", body)
             |> valid_response(404)
    end

    test "returns 403 for a member", %{conn: conn, community: community} do
      member = TestUtils.join_random_member!(community)
      body = %{kinds: TestUtils.kinds_input(community)}

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/communities/#{community.id}/kinds", body)
               |> valid_response(403)
    end

    test "returns 400 without discussion", %{conn: conn, owner: owner, community: community} do
      body = %{kinds: TestUtils.kinds_input(community, without: ["discussion"])}

      assert %{"code" => "keeps_discussion"} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/kinds", body)
               |> valid_response(400)
    end

    test "saves the kinds", %{conn: conn, owner: owner, community: community} do
      added = %{label: "Trip report", icon: "map", hue: "green"}
      body = %{kinds: [added | TestUtils.kinds_input(community)]}

      response =
        conn
        |> auth_conn(owner)
        |> put(~p"/api/communities/#{community.id}/kinds", body)
        |> valid_response(200)

      assert "trip-report" in TestUtils.pluck(response, "key")
    end
  end
end
