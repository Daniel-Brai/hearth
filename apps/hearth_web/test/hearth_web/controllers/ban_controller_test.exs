defmodule HearthWeb.BanControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Moderation
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner, moderation: :reports)
    member = TestUtils.join_random_member!(community)

    {:ok, binding()}
  end

  describe "index" do
    test "fails without member.ban", %{conn: conn, member: member, community: community} do
      assert conn
             |> auth_conn(member)
             |> get(~p"/api/communities/#{community.id}/bans")
             |> valid_response(403)
    end

    test "lists the bans in force", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community
    } do
      {:ok, _ban} = Moderation.ban(owner, community, member, %{reason: Lorem.sentence()})

      assert [%{"banned_by" => %{}} = ban] =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/communities/#{community.id}/bans")
               |> valid_response(200)

      assert ban["user"]["username"] == member.username
    end
  end

  describe "create" do
    test "fails without a reason", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community
    } do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/bans", %{username: member.username})
               |> valid_response(422)

      assert ["The reason field is required."] = errors["reason"]
    end

    test "fails for the Owner", %{conn: conn, owner: owner, community: community} do
      banner = TestUtils.join_with_permissions!(community, ["member.ban"])
      body = %{username: owner.username, reason: Lorem.sentence()}

      assert conn
             |> auth_conn(banner)
             |> post(~p"/api/communities/#{community.id}/bans", body)
             |> valid_response(403)
    end

    test "bans by username", %{conn: conn, owner: owner, member: member, community: community} do
      expires_at = DateTime.utc_now() |> DateTime.add(7, :day) |> DateTime.to_iso8601()
      body = %{username: "@" <> member.username, reason: Lorem.sentence(), expires_at: expires_at}

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/bans", body)
               |> valid_response(201)

      assert response["reason"] == body.reason
      assert response["user"]["id"] == member.id
    end
  end

  describe "lift" do
    test "fails without member.ban", %{
      conn: conn,
      owner: owner,
      member: member,
      community: community
    } do
      {:ok, ban} = Moderation.ban(owner, community, member, %{reason: Lorem.sentence()})
      other = TestUtils.join_random_member!(community)

      assert conn
             |> auth_conn(other)
             |> post(~p"/api/bans/#{ban.id}/lift", %{})
             |> valid_response(403)
    end

    test "lifts the ban", %{conn: conn, owner: owner, member: member, community: community} do
      {:ok, ban} = Moderation.ban(owner, community, member, %{reason: Lorem.sentence()})

      assert %{"lifted_at" => lifted_at} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/bans/#{ban.id}/lift", %{reason: Lorem.sentence()})
               |> valid_response(200)

      assert lifted_at
    end
  end
end
