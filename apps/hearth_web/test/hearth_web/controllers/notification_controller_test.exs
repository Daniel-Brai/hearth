defmodule HearthWeb.NotificationControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.TestUtils

  setup do
    user = TestUtils.register_random_user!()
    actor = TestUtils.register_random_user!()
    notification = TestUtils.create_random_notification!(user, actor_id: actor.id)

    {:ok, binding()}
  end

  describe "index" do
    test "fails without signing in", %{conn: conn} do
      assert conn |> get(~p"/api/notifications") |> valid_response(401)
    end

    test "lists notifications with actors", %{
      conn: conn,
      user: user,
      notification: notification
    } do
      assert response =
               conn |> auth_conn(user) |> get(~p"/api/notifications") |> valid_response(200)

      assert %{"data" => [entry], "unread" => 1} = response
      assert entry["id"] == notification.id
      assert entry["actor"]["id"] == notification.actor_id
    end
  end

  describe "read" do
    test "marks one read", %{conn: conn, user: user, notification: notification} do
      assert conn
             |> auth_conn(user)
             |> post(~p"/api/notifications/#{notification.id}/read")
             |> response(204)

      assert %{"unread" => 0} =
               conn |> auth_conn(user) |> get(~p"/api/notifications") |> valid_response(200)
    end
  end

  describe "read_all" do
    test "marks every one read", %{conn: conn, user: user} do
      _second = TestUtils.create_random_notification!(user)

      assert conn |> auth_conn(user) |> post(~p"/api/notifications/read") |> response(204)

      assert %{"unread" => 0} =
               conn |> auth_conn(user) |> get(~p"/api/notifications") |> valid_response(200)
    end
  end
end
