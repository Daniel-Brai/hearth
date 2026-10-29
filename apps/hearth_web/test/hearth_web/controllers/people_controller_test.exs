defmodule HearthWeb.PeopleControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Accounts
  alias Hearth.TestUtils
  alias HearthWeb.Presence

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)

    {:ok, binding()}
  end

  describe "index" do
    test "fails without signing in", %{conn: conn} do
      assert conn |> get(~p"/api/people") |> valid_response(401)
    end

    test "fails for a community that isn't an id", %{conn: conn, owner: owner} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/people?community=nope")
               |> valid_response(422)

      assert [_message] = errors["community"]
    end

    test "leaves out people with no community in common", %{conn: conn, owner: owner} do
      _stranger = TestUtils.join_random_member!(TestUtils.create_random_community!())

      assert [person] = conn |> auth_conn(owner) |> get(~p"/api/people") |> valid_response(200)
      refute person["id"] == owner.id
    end

    test "hides presence and communities when asked", %{conn: conn, owner: owner, member: member} do
      changes = %{presence: :nobody, last_seen: :nobody, show_communities: :nobody}
      {:ok, _privacy} = Accounts.update_privacy(member, changes)

      {:ok, _ref} = Presence.track_user(self(), member.id)

      assert [person] = conn |> auth_conn(owner) |> get(~p"/api/people") |> valid_response(200)
      assert %{"online" => false, "last_seen_at" => nil, "community_ids" => []} = person
    end

    test "lists people with the communities shared", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community
    } do
      {:ok, _ref} = Presence.track_user(self(), member.id)

      assert [person] = conn |> auth_conn(owner) |> get(~p"/api/people") |> valid_response(200)
      assert %{"online" => true, "community_ids" => [community_id]} = person
      assert person["id"] == member.id
      assert community_id == community.id
    end
  end
end
