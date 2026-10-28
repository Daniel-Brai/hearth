defmodule HearthWeb.PushSubscriptionControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.TestUtils

  setup do
    {:ok, user: TestUtils.register_random_user!()}
  end

  describe "create" do
    test "fails for an address that isn't https", %{conn: conn, user: user} do
      body = TestUtils.random_push_sub_params("http://push.example.com/1")

      assert %{"errors" => errors} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/push-subscriptions", body)
               |> valid_response(422)

      assert ["must be an https address"] = errors["endpoint"]
    end

    test "saves the device", %{conn: conn, user: user} do
      body = TestUtils.random_push_sub_params()

      assert conn
             |> auth_conn(user)
             |> post(~p"/api/push-subscriptions", body)
             |> response(204)
    end
  end

  describe "delete" do
    test "forgets the device", %{conn: conn, user: user} do
      %{endpoint: endpoint} = TestUtils.link_random_push_sub!(user)

      assert conn
             |> auth_conn(user)
             |> delete(~p"/api/push-subscriptions", %{endpoint: endpoint})
             |> response(204)
    end
  end
end
