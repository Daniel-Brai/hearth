defmodule HearthWeb.MediaControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Common
  alias Hearth.TestUtils

  setup do
    user = TestUtils.register_random_user!()

    media =
      TestUtils.upload_random_file!(user, :pdf)

    {:ok, binding()}
  end

  describe "show" do
    test "returns 404 if missing", %{conn: conn, user: user} do
      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(user)
               |> get(~p"/api/media/#{Common.new_id()}")
               |> valid_response(404)
    end

    test "returns 404 for someone else's file", %{conn: conn, media: media} do
      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> get(~p"/api/media/#{media.id}")
               |> valid_response(404)
    end

    test "shows a ready file with its URLs", %{conn: conn, media: media, user: user} do
      assert response =
               conn
               |> auth_conn(user)
               |> get(~p"/api/media/#{media.id}")
               |> valid_response(200)

      assert response["status"] == "ready"
      assert response["urls"]["original"] =~ media.bucket_key
    end
  end

  describe "delete" do
    test "returns 404 if missing", %{conn: conn, user: user} do
      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(user)
               |> delete(~p"/api/media/#{Common.new_id()}")
               |> valid_response(404)
    end

    test "deletes the file", %{conn: conn, media: media, user: user} do
      assert conn |> auth_conn(user) |> delete(~p"/api/media/#{media.id}") |> response(204)
      assert conn |> auth_conn(user) |> get(~p"/api/media/#{media.id}") |> valid_response(404)
    end
  end
end
