defmodule HearthWeb.UploadControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Common
  alias Hearth.Media
  alias Hearth.Storage
  alias Hearth.TestUtils

  setup do
    user = TestUtils.register_random_user!()
    png = TestUtils.random_file!()

    {:ok, binding()}
  end

  describe "create" do
    test "fails without signing in", %{conn: conn} do
      body = :png |> TestUtils.random_upload_params() |> Map.delete(:idempotency_key)

      assert %{"code" => "missing_token"} =
               conn
               |> put_req_header("idempotency-key", Common.new_id())
               |> post(~p"/api/uploads", body)
               |> valid_response(401)
    end

    test "fails due to validation", %{conn: conn, user: user} do
      body = %{name: "", content_type: "image/png", byte_size: 0, sha256: "nope"}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(user)
               |> put_req_header("idempotency-key", Common.new_id())
               |> post(~p"/api/uploads", body)
               |> valid_response(422)

      assert Map.keys(errors) -- ~w[name byte_size sha256] == []
    end

    test "fails without an idempotency key", %{conn: conn, user: user} do
      body = :png |> TestUtils.random_upload_params() |> Map.delete(:idempotency_key)

      assert %{"errors" => errors} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/uploads", body)
               |> valid_response(422)

      assert [_message] = errors["idempotency_key"]
    end

    test "fails for a type that can't be uploaded", %{conn: conn, user: user} do
      body =
        :png
        |> TestUtils.random_upload_params(content_type: "application/x-msdownload")
        |> Map.delete(:idempotency_key)

      assert %{"errors" => errors} =
               conn
               |> auth_conn(user)
               |> put_req_header("idempotency-key", Common.new_id())
               |> post(~p"/api/uploads", body)
               |> valid_response(422)

      assert [_message] = errors["content_type"]
    end

    test "starts an upload", %{conn: conn, user: user} do
      body = :png |> TestUtils.random_upload_params() |> Map.delete(:idempotency_key)

      assert response =
               conn
               |> auth_conn(user)
               |> put_req_header("idempotency-key", Common.new_id())
               |> post(~p"/api/uploads", body)
               |> valid_response(201)

      assert response["media"]["status"] == "uploading"
      assert response["upload"]["headers"]["content-type"] == body.content_type
    end

    test "returns the same file for the same key", %{conn: conn, user: user} do
      body = :png |> TestUtils.random_upload_params() |> Map.delete(:idempotency_key)
      key = Common.new_id()

      assert %{"media" => %{"id" => id}} =
               conn
               |> auth_conn(user)
               |> put_req_header("idempotency-key", key)
               |> post(~p"/api/uploads", body)
               |> valid_response(201)

      assert %{"media" => %{"id" => ^id}} =
               conn
               |> auth_conn(user)
               |> put_req_header("idempotency-key", key)
               |> post(~p"/api/uploads", body)
               |> valid_response(201)
    end
  end

  describe "part_urls" do
    test "returns 404 for someone else's upload", %{conn: conn, user: user} do
      owner = TestUtils.register_random_user!()
      params = TestUtils.random_upload_params()
      {:ok, %{media: media}} = Media.request_upload(owner, params)

      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/uploads/#{media.id}/part-urls", %{numbers: [1]})
               |> valid_response(404)
    end

    test "fails for a single upload", %{conn: conn, user: user} do
      params = TestUtils.random_upload_params()
      {:ok, %{media: media}} = Media.request_upload(user, params)

      assert %{"code" => "not_multipart"} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/uploads/#{media.id}/part-urls", %{numbers: [1]})
               |> valid_response(400)
    end

    test "signs each part", %{conn: conn, user: user} do
      params = TestUtils.random_upload_params(:pdf, byte_size: 3 * 1024 * 1024)
      {:ok, %{media: media}} = Media.request_upload(user, params)

      assert %{"urls" => %{"1" => _url}} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/uploads/#{media.id}/part-urls", %{numbers: [1]})
               |> valid_response(200)

      assert %{"parts" => []} =
               conn
               |> auth_conn(user)
               |> get(~p"/api/uploads/#{media.id}/parts")
               |> valid_response(200)
    end
  end

  describe "complete" do
    test "returns 404 if missing", %{conn: conn, user: user} do
      assert %{"message" => "Not Found"} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/uploads/#{Common.new_id()}/complete", %{})
               |> valid_response(404)
    end

    test "fails before the file is stored", %{conn: conn, user: user} do
      params = TestUtils.random_upload_params()
      {:ok, %{media: media}} = Media.request_upload(user, params)

      assert %{"code" => "not_uploaded"} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/uploads/#{media.id}/complete", %{})
               |> valid_response(400)
    end

    test "queues the file to be processed", %{conn: conn, user: user, png: png} do
      params = TestUtils.random_upload_params()
      {:ok, %{media: media}} = Media.request_upload(user, params)

      :ok = Storage.put(media.bucket_key, png, "image/png")

      assert %{"status" => "processing"} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/uploads/#{media.id}/complete", %{})
               |> valid_response(200)
    end
  end
end
