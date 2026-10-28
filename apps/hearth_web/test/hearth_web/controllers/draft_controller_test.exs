defmodule HearthWeb.DraftControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Common
  alias Hearth.Forum
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner)

    {:ok, binding()}
  end

  describe "index" do
    test "fails without signing in", %{conn: conn} do
      assert conn |> get(~p"/api/drafts") |> valid_response(401)
    end

    test "lists my drafts with their kind", %{conn: conn, owner: owner, community: community} do
      [kind | _kinds] = Forum.list_kinds(community.id)
      params = %{title: Lorem.sentence(), kind_id: kind.id}
      {:ok, _draft} = Forum.save_draft(owner, community, params)

      assert [draft] = conn |> auth_conn(owner) |> get(~p"/api/drafts") |> valid_response(200)
      assert draft["community_id"] == community.id
      assert draft["kind"] == kind.label
    end
  end

  describe "update" do
    test "fails outside the community", %{conn: conn, community: community} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> put(~p"/api/communities/#{community.id}/draft", %{title: Lorem.sentence()})
               |> valid_response(403)
    end

    test "returns 404 if missing", %{conn: conn, owner: owner} do
      assert conn
             |> auth_conn(owner)
             |> put(~p"/api/communities/#{Common.new_id()}/draft", %{title: Lorem.sentence()})
             |> valid_response(404)
    end

    test "saves the draft", %{conn: conn, owner: owner, community: community} do
      body = %{title: Lorem.sentence(), body: Lorem.paragraph()}

      assert response =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/draft", body)
               |> valid_response(200)

      assert response["title"] == body.title
      assert response["body"] == body.body
    end
  end

  describe "delete" do
    test "throws the draft away", %{conn: conn, owner: owner, community: community} do
      {:ok, _draft} = Forum.save_draft(owner, community, %{title: Lorem.sentence()})

      assert conn
             |> auth_conn(owner)
             |> delete(~p"/api/communities/#{community.id}/draft")
             |> response(204)

      assert [] = Forum.list_drafts(owner)
    end
  end
end
