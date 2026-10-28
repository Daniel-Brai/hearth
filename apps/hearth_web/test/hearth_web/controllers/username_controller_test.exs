defmodule HearthWeb.UsernameControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.TestUtils

  describe "show" do
    test "says a taken username isn't free", %{conn: conn} do
      user = TestUtils.register_random_user!()

      assert %{"available" => false} =
               conn |> get(~p"/api/usernames/#{user.username}") |> valid_response(200)
    end

    test "says invalid username is not free", %{conn: conn} do
      assert %{"available" => false} =
               conn |> get(~p"/api/usernames/No Spaces") |> valid_response(200)
    end

    test "says a free username is free", %{conn: conn} do
      assert %{"available" => true} =
               conn
               |> get(~p"/api/usernames/#{TestUtils.random_username()}")
               |> valid_response(200)
    end
  end
end
