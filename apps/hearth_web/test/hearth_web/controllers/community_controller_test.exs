defmodule HearthWeb.CommunityControllerTest do
  use HearthWeb.ConnCase, async: true
  use Oban.Testing, repo: Hearth.Repo

  alias Faker.Company
  alias Faker.Lorem
  alias Hearth.Auth
  alias Hearth.Auth.TransferCodeRequested
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Media.Worker.ProcessImage
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)

    {:ok, binding()}
  end

  describe "index" do
    test "fails without signing in", %{conn: conn} do
      assert %{"code" => "missing_token"} =
               conn |> get(~p"/api/communities") |> valid_response(401)
    end

    test "lists the communities joined", %{conn: conn, owner: owner, community: community} do
      assert [%{"id" => id, "rooms" => [_room | _rooms]}] =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/communities")
               |> valid_response(200)

      assert id == community.id
    end
  end

  describe "public" do
    test "lists public communities signed out", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      _invite = TestUtils.create_random_community!(owner, visibility: :invite_only)

      assert [%{"id" => id, "rooms" => [_room | _rooms]}] =
               conn |> get(~p"/api/public/communities") |> valid_response(200)

      assert id == community.id
    end

    test "shows owner members and logo", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      logo = TestUtils.upload_random_file!(owner, width: 400, height: 400, purpose: :logo)

      :ok = perform_job(ProcessImage, %{media_id: logo.id})
      {:ok, _community} = Communities.update_community(owner, community, %{logo_id: logo.id})

      assert [response] = conn |> get(~p"/api/public/communities") |> valid_response(200)

      assert %{"owner" => %{"id" => owner_id}, "member_count" => 1, "banner_url" => nil} =
               response

      assert owner_id == owner.id
      assert is_binary(response["logo_url"])
    end
  end

  describe "create" do
    test "fails due to validation", %{conn: conn} do
      admin = TestUtils.register_random_user!(admin: true)
      body = %{name: "x", template: "nope"}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(admin)
               |> post(~p"/api/communities", body)
               |> valid_response(422)

      assert Map.has_key?(errors, "name")
      assert Map.has_key?(errors, "template")
    end

    test "fails where only admins start communities", %{conn: conn} do
      TestUtils.put_community_creation("admins")

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/communities", %{name: Company.name()})
               |> valid_response(403)
    end

    test "starts one with its description and logo", %{conn: conn} do
      user = TestUtils.register_random_user!(admin: true)

      logo = TestUtils.upload_random_file!(user)

      body = %{name: Company.name(), description: Lorem.paragraph(), logo_id: logo.id}

      assert response =
               conn |> auth_conn(user) |> post(~p"/api/communities", body) |> valid_response(201)

      assert response["description"] == body.description
      assert response["logo_id"] == logo.id
    end

    test "asks for one if requests are on", %{conn: conn} do
      TestUtils.put_community_creation("request")
      body = %{name: Company.name(), description: Lorem.paragraph()}

      assert response =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/communities", body)
               |> valid_response(202)

      assert response["status"] == "pending"
    end
  end

  describe "slug" do
    test "fails without a name", %{conn: conn, owner: owner} do
      assert %{"errors" => errors} =
               conn |> auth_conn(owner) |> get(~p"/api/community-slugs") |> valid_response(422)

      assert ["The name field is required."] = errors["name"]
    end

    test "numbers a taken name", %{conn: conn, owner: owner, community: community} do
      assert %{"slug" => slug} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/community-slugs?name=#{community.name}")
               |> valid_response(200)

      assert slug == community.slug <> "-2"
    end
  end

  describe "show" do
    test "returns 404 if missing", %{conn: conn} do
      assert %{"message" => "Not Found"} =
               conn |> get(~p"/api/communities/#{Common.new_id()}") |> valid_response(404)
    end

    test "returns 404 if private", %{conn: conn, owner: owner} do
      private = TestUtils.create_random_community!(owner, visibility: :private)

      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> get(~p"/api/communities/#{private.id}")
               |> valid_response(404)
    end

    test "shows outline of invite only to outsiders", %{
      conn: conn,
      owner: owner
    } do
      community =
        TestUtils.create_random_forum!(owner,
          visibility: :invite_only,
          description: Lorem.paragraph()
        )

      assert %{"community" => outline, "kinds" => [], "membership" => nil} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> get(~p"/api/communities/#{community.id}")
               |> valid_response(200)

      assert outline["name"] == community.name

      assert %{"description" => nil, "welcome_message" => nil, "links" => [], "rooms" => []} =
               outline
    end

    test "shows invite only to members", %{conn: conn, owner: owner} do
      community = TestUtils.create_random_forum!(owner, visibility: :invite_only)

      assert %{"kinds" => [_kind | _kinds]} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/communities/#{community.id}")
               |> valid_response(200)
    end

    test "shows public community by slug", %{conn: conn, community: community} do
      assert response =
               conn |> get(~p"/api/communities/#{community.slug}") |> valid_response(200)

      assert response["community"]["id"] == community.id
    end

    test "shows the member's roles and permissions", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      assert %{"membership" => %{"roles" => roles, "permissions" => permissions}} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/communities/#{community.id}")
               |> valid_response(200)

      assert [%{"key" => "owner"}] = roles
      assert "post.pin" in permissions
    end
  end

  describe "update" do
    test "fails if not the owner", %{conn: conn, community: community} do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/communities/#{community.id}", %{tagline: Lorem.sentence()})
               |> valid_response(403)
    end

    test "clears a field sent as null", %{conn: conn, owner: owner, community: community} do
      changes = %{tagline: Lorem.sentence()}
      {:ok, _community} = Communities.update_community(owner, community, changes)

      body = %{tagline: nil}

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/communities/#{community.id}", body)
               |> valid_response(200)

      assert response["tagline"] == nil
    end
  end

  describe "join" do
    test "fails for a community that needs an invite", %{conn: conn, owner: owner} do
      closed = TestUtils.create_random_community!(owner, visibility: :invite_only)

      assert %{"code" => "invite_required"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/communities/#{closed.id}/membership")
               |> valid_response(400)
    end

    test "joins an open community", %{conn: conn, community: community} do
      assert %{"roles" => _roles, "permissions" => permissions} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/communities/#{community.id}/membership")
               |> valid_response(201)

      assert "post.create" in permissions
    end
  end

  describe "leave" do
    test "fails for the owner", %{conn: conn, owner: owner, community: community} do
      assert %{"code" => "owner"} =
               conn
               |> auth_conn(owner)
               |> delete(~p"/api/communities/#{community.id}/membership")
               |> valid_response(400)
    end

    test "leaves", %{conn: conn, community: community} do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert conn
             |> auth_conn(member)
             |> delete(~p"/api/communities/#{community.id}/membership")
             |> response(204)
    end
  end

  describe "transfer_code" do
    test "fails if not the owner", %{conn: conn, community: community} do
      member = TestUtils.join_random_member!(community)

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/communities/#{community.id}/owner/code")
               |> valid_response(403)
    end

    test "emails the owner a code", %{conn: conn, owner: owner, community: community} do
      :ok = Auth.subscribe_to_pubsub()
      id = owner.id

      assert conn
             |> auth_conn(owner)
             |> post(~p"/api/communities/#{community.id}/owner/code")
             |> response(204)

      assert_receive %TransferCodeRequested{user_id: ^id}
    end
  end

  describe "transfer" do
    test "fails if not the owner", %{conn: conn, community: community} do
      member = TestUtils.join_random_member!(community)
      body = %{user_id: member.id, code: "123456"}

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/communities/#{community.id}/owner", body)
               |> valid_response(403)
    end

    test "fails without a code", %{conn: conn, owner: owner, community: community} do
      member = TestUtils.join_random_member!(community)

      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/owner", %{user_id: member.id})
               |> valid_response(422)

      assert ["The code field is required."] = errors["code"]
    end

    test "fails if code is wrong", %{conn: conn, owner: owner, community: community} do
      member = TestUtils.join_random_member!(community)
      body = %{user_id: member.id, code: "000000"}

      assert %{"code" => "invalid_code"} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/owner", body)
               |> valid_response(400)
    end

    test "fails for someone outside", %{conn: conn, owner: owner, community: community} do
      outsider = TestUtils.register_random_user!()
      code = TestUtils.transfer_code!(owner, community)
      body = %{user_id: outsider.id, code: code}

      assert %{"code" => "not_a_member"} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/owner", body)
               |> valid_response(400)
    end

    test "hands it over", %{conn: conn, owner: owner, community: community} do
      member = TestUtils.join_random_member!(community)
      body = %{user_id: member.id, code: TestUtils.transfer_code!(owner, community)}

      assert response =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/communities/#{community.id}/owner", body)
               |> valid_response(200)

      assert response["owner_id"] == member.id
    end
  end
end
