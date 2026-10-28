defmodule HearthWeb.InviteControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Internet
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, visibility: :private)
    {:ok, invite} = Communities.create_invite(owner, community, %{})

    {:ok, binding()}
  end

  describe "index" do
    test "fails for someone outside the community", %{conn: conn, community: community} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> get(~p"/api/communities/#{community.id}/invites")
               |> valid_response(403)
    end

    test "lists links and emailed invites", %{
      conn: conn,
      owner: owner,
      community: community,
      invite: invite
    } do
      email = Internet.email()

      {:ok, _sent} =
        Communities.email_invites(owner, community, [%{email: email, role_key: "member"}])

      assert %{"links" => [link], "emails" => [emailed]} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/communities/#{community.id}/invites")
               |> valid_response(200)

      assert link["code"] == invite.code
      assert emailed["email"] == email
      assert emailed["status"] == "pending"
    end
  end

  describe "create" do
    test "fails for someone outside the community", %{conn: conn, community: community} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/communities/#{community.id}/invites", %{})
               |> valid_response(403)
    end

    test "makes an invite link", %{conn: conn, owner: owner, community: community} do
      body = %{max_uses: 5}

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/invites", body)
               |> valid_response(201)

      assert is_binary(response["code"])
      assert response["role_key"] == "member"
      assert response["max_uses"] == body.max_uses
    end
  end

  describe "show" do
    test "returns 404 if missing", %{conn: conn} do
      assert %{"message" => "Not Found"} =
               conn |> get(~p"/api/invites/nope") |> valid_response(404)
    end

    test "shows private name with link", %{
      conn: conn,
      community: community,
      invite: invite,
      owner: owner
    } do
      assert response = conn |> get(~p"/api/invites/#{invite.code}") |> valid_response(200)

      assert response["usable"] == true
      assert response["role_key"] == "member"
      assert response["inviter"]["username"] == owner.username
      assert response["role_name"] == "Member"
      assert response["community"]["member_count"] == 1
      assert response["community"]["name"] == community.name
    end
  end

  describe "accept" do
    test "fails for a revoked invite", %{conn: conn, owner: owner, invite: invite} do
      {:ok, _invite} = Communities.revoke_invite(owner, invite)

      assert %{"code" => "revoked"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/invites/#{invite.code}/accept")
               |> valid_response(400)
    end

    test "joins the community", %{conn: conn, invite: invite} do
      assert %{"permissions" => [_permission | _permissions]} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/invites/#{invite.code}/accept")
               |> valid_response(201)
    end
  end

  describe "delete" do
    test "revokes an invite", %{conn: conn, owner: owner, invite: invite} do
      assert %{"revoked_at" => revoked_at} =
               conn
               |> auth_conn(owner)
               |> delete(~p"/api/invites/#{invite.code}")
               |> valid_response(200)

      assert revoked_at
    end
  end

  describe "update" do
    test "fails for someone outside the community", %{conn: conn, invite: invite} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> patch(~p"/api/invites/#{invite.code}", %{max_uses: 10})
               |> valid_response(403)
    end

    test "changes the link", %{conn: conn, owner: owner, invite: invite} do
      body = %{max_uses: 10, role_key: "moderator"}

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/invites/#{invite.code}", body)
               |> valid_response(200)

      assert response["code"] == invite.code
      assert response["max_uses"] == body.max_uses
      assert response["role_key"] == body.role_key
    end
  end

  describe "email_create" do
    test "fails due to validation", %{conn: conn, owner: owner, community: community} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/invite-emails", %{emails: []})
               |> valid_response(422)

      assert [_message] = errors["emails"]
    end

    test "emails an invite to each address", %{conn: conn, owner: owner, community: community} do
      email = Internet.email()
      body = %{emails: [%{email: email, role_key: "member"}]}

      assert [sent] =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/invite-emails", body)
               |> valid_response(201)

      assert sent["email"] == email
      assert sent["role_key"] == "member"
    end
  end

  describe "email_delete" do
    test "returns 404 if missing", %{conn: conn, owner: owner} do
      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(owner)
               |> delete(~p"/api/invite-emails/#{Common.new_id()}")
               |> valid_response(404)
    end

    test "revokes the emailed invite", %{conn: conn, owner: owner, community: community} do
      {:ok, [sent]} =
        Communities.email_invites(owner, community, [
          %{email: Internet.email(), role_key: "member"}
        ])

      assert %{"status" => "revoked"} =
               conn
               |> auth_conn(owner)
               |> delete(~p"/api/invite-emails/#{sent.id}")
               |> valid_response(200)
    end
  end

  describe "mine" do
    test "fails without signing in", %{conn: conn} do
      assert conn |> get(~p"/api/auth/me/invites") |> valid_response(401)
    end

    test "lists the invites waiting for the person", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      user = TestUtils.register_random_user!()

      {:ok, [sent]} =
        Communities.email_invites(owner, community, [%{email: user.email, role_key: "member"}])

      assert [response] =
               conn |> auth_conn(user) |> get(~p"/api/auth/me/invites") |> valid_response(200)

      assert response["code"] == sent.invite.code
      assert response["community"]["name"] == community.name
      assert response["inviter"]["id"] == owner.id
    end
  end

  describe "email_decline" do
    test "returns 404 for someone else's invite", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      {:ok, [sent]} =
        Communities.email_invites(owner, community, [
          %{email: Internet.email(), role_key: "member"}
        ])

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> post(~p"/api/invite-emails/#{sent.id}/decline")
             |> valid_response(404)
    end

    test "turns the invite down", %{conn: conn, owner: owner, community: community} do
      user = TestUtils.register_random_user!()

      {:ok, [sent]} =
        Communities.email_invites(owner, community, [%{email: user.email, role_key: "member"}])

      assert conn
             |> auth_conn(user)
             |> post(~p"/api/invite-emails/#{sent.id}/decline")
             |> response(204)

      assert [] = conn |> auth_conn(user) |> get(~p"/api/auth/me/invites") |> valid_response(200)
    end
  end
end
