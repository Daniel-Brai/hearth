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

  describe "subscribe_push" do
    setup do
      {:ok, user: TestUtils.register_random_user!()}
    end

    test "fails for an address that isn't https", %{conn: conn, user: user} do
      body = TestUtils.random_push_sub_params("http://push.example.com/1")

      assert %{"errors" => errors} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/notifications/push-subscriptions", body)
               |> valid_response(422)

      assert ["must be an https address"] = errors["endpoint"]
    end

    test "saves the device", %{conn: conn, user: user} do
      body = TestUtils.random_push_sub_params()

      assert conn
             |> auth_conn(user)
             |> post(~p"/api/notifications/push-subscriptions", body)
             |> response(204)
    end
  end

  describe "unsubscribe_push" do
    setup do
      {:ok, user: TestUtils.register_random_user!()}
    end

    test "forgets the device", %{conn: conn, user: user} do
      %{endpoint: endpoint} = TestUtils.link_random_push_sub!(user)

      assert conn
             |> auth_conn(user)
             |> delete(~p"/api/notifications/push-subscriptions", %{endpoint: endpoint})
             |> response(204)
    end
  end
end
