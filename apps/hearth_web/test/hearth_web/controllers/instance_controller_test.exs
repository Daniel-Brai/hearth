defmodule HearthWeb.InstanceControllerTest do
  use HearthWeb.ConnCase, async: true

  import Req.Test

  alias Hearth.Instance.Releases
  alias Hearth.TestUtils
  alias Plug.Conn

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  describe "show" do
    test "shows what the instance has set up", %{conn: conn} do
      assert response =
               conn
               |> get(~p"/api/instance")
               |> valid_response(200)

      assert response["name"] == "Hearth"
      assert "email" in response["sign_in"]
      assert response["upload_limits"]["max_video_bytes"] == 100 * 1024 * 1024
      assert response["upload_limits"]["max_video_seconds"] == 20 * 60
      assert %{"enabled" => true, "image_floor" => false} = response["screening"]
      assert %{"enabled" => true} = response["transcription"]
      assert %{"enabled" => false} = response["voice"]
    end

    test "lists the roles some node in the cluster runs", %{conn: conn} do
      assert %{"roles" => ["web", "media", "ai"]} =
               conn |> get(~p"/api/instance") |> valid_response(200)
    end
  end

  describe "update" do
    test "fails for someone who isn't an instance admin", %{conn: conn} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> patch(~p"/api/instance", %{community_creation: "anyone"})
               |> valid_response(403)
    end

    test "fails due to validation", %{conn: conn} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(TestUtils.register_random_user!(admin: true))
               |> patch(~p"/api/instance", %{community_creation: "everyone"})
               |> valid_response(422)

      assert [_message] = errors["community_creation"]
    end

    test "changes who may start a community", %{conn: conn} do
      assert %{"community_creation" => "request"} =
               conn
               |> auth_conn(TestUtils.register_random_user!(admin: true))
               |> patch(~p"/api/instance", %{community_creation: "request"})
               |> valid_response(200)
    end
  end

  describe "update_status" do
    test "fails for someone who isn't an instance admin", %{conn: conn} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> get(~p"/api/instance/update")
               |> valid_response(403)
    end

    test "shows running version before check", %{conn: conn} do
      assert %{"current_version" => "0.1.0", "update_available" => false} =
               conn
               |> auth_conn(TestUtils.register_random_user!(admin: true))
               |> get(~p"/api/instance/update")
               |> valid_response(200)
    end
  end

  describe "check_update" do
    test "fails for someone who isn't an instance admin", %{conn: conn} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/instance/update/check")
               |> valid_response(403)
    end

    test "fails when GitHub doesn't answer", %{conn: conn} do
      stub(Releases, &Conn.send_resp(&1, 502, ""))

      assert %{"code" => "github_unreachable"} =
               conn
               |> auth_conn(TestUtils.register_random_user!(admin: true))
               |> post(~p"/api/instance/update/check")
               |> valid_response(400)
    end

    test "finds a newer release", %{conn: conn} do
      stub(Releases, &json(&1, TestUtils.random_github_release("v0.2.0")))

      assert %{"latest_version" => "0.2.0", "update_available" => true} =
               conn
               |> auth_conn(TestUtils.register_random_user!(admin: true))
               |> post(~p"/api/instance/update/check")
               |> valid_response(200)
    end
  end
end
