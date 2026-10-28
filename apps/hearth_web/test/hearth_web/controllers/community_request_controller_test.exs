defmodule HearthWeb.CommunityRequestControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Company
  alias Faker.Lorem
  alias Hearth.Common
  alias Hearth.Communities.Request
  alias Hearth.TestUtils

  setup do
    admin = TestUtils.register_random_user!(admin: true)
    requester = TestUtils.register_random_user!()
    params = %{name: Company.name(), template: "club", note: Lorem.sentence()}
    {:ok, request} = Request.insert(%Request{requester_id: requester.id}, params)

    {:ok, binding()}
  end

  describe "index" do
    test "fails if not an instance admin", %{conn: conn, requester: requester} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(requester)
               |> get(~p"/api/community-requests")
               |> valid_response(403)
    end

    test "fails for an unknown status", %{conn: conn, admin: admin} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(admin)
               |> get(~p"/api/community-requests?status=lost")
               |> valid_response(422)

      assert [_message] = errors["status"]
    end

    test "lists waiting requests", %{conn: conn, admin: admin, requester: requester} do
      assert [response] =
               conn
               |> auth_conn(admin)
               |> get(~p"/api/community-requests")
               |> valid_response(200)

      assert response["status"] == "pending"
      assert response["requester"]["id"] == requester.id
    end

    test "lists decided requests", %{conn: conn, admin: admin} do
      assert [] =
               conn
               |> auth_conn(admin)
               |> get(~p"/api/community-requests?status=declined")
               |> valid_response(200)
    end
  end

  describe "decide" do
    test "fails if not an instance admin", %{conn: conn, requester: requester, request: request} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(requester)
               |> post(~p"/api/community-requests/#{request.id}/decision", %{decision: "approved"})
               |> valid_response(403)
    end

    test "returns 404 if missing", %{conn: conn, admin: admin} do
      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(admin)
               |> post(~p"/api/community-requests/#{Common.new_id()}/decision", %{
                 decision: "declined"
               })
               |> valid_response(404)
    end

    test "fails without a decision", %{conn: conn, admin: admin, request: request} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(admin)
               |> post(~p"/api/community-requests/#{request.id}/decision", %{})
               |> valid_response(422)

      assert ["The decision field is required."] = errors["decision"]
    end

    test "fails if already decided", %{conn: conn, admin: admin, request: request} do
      conn
      |> auth_conn(admin)
      |> post(~p"/api/community-requests/#{request.id}/decision", %{decision: "declined"})
      |> valid_response(200)

      assert %{"code" => "already_decided"} =
               conn
               |> auth_conn(admin)
               |> post(~p"/api/community-requests/#{request.id}/decision", %{decision: "approved"})
               |> valid_response(400)
    end

    test "declines", %{conn: conn, admin: admin, request: request} do
      assert response =
               conn
               |> auth_conn(admin)
               |> post(~p"/api/community-requests/#{request.id}/decision", %{decision: "declined"})
               |> valid_response(200)

      assert response["status"] == "declined"
      assert response["community_id"] == nil
    end

    test "approves", %{conn: conn, admin: admin, request: request} do
      assert response =
               conn
               |> auth_conn(admin)
               |> post(~p"/api/community-requests/#{request.id}/decision", %{decision: "approved"})
               |> valid_response(200)

      assert response["status"] == "approved"
      assert response["community_id"]
      assert response["community_slug"]
    end
  end
end
