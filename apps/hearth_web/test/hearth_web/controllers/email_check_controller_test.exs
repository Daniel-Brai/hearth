defmodule HearthWeb.EmailCheckControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.TestUtils

  describe "create" do
    test "fails without signing in", %{conn: conn} do
      assert conn
             |> post(~p"/api/emails/check", %{emails: ["a@example.org"]})
             |> valid_response(401)
    end

    test "fails due to validation", %{conn: conn} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/emails/check", %{emails: []})
               |> valid_response(422)

      assert "The emails field must be at least 1 items." in errors["emails"]
    end

    test "says which addresses can't receive email", %{conn: conn} do
      body = %{emails: ["ada@example.org", "bo@typo.invalid", "nope"]}

      assert response =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/emails/check", body)
               |> valid_response(200)

      assert response == [
               %{"email" => "ada@example.org", "status" => "unknown"},
               %{"email" => "bo@typo.invalid", "status" => "unreachable"},
               %{"email" => "nope", "status" => "invalid"}
             ]
    end
  end
end
