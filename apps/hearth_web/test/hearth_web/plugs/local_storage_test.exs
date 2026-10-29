defmodule HearthWeb.Plugs.LocalStorageTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Common
  alias Hearth.Storage

  setup do
    {:ok, key: "test/#{Common.new_id()}/clip.mp4"}
  end

  describe "PUT" do
    test "fails if the signature is wrong", %{conn: conn, key: key} do
      {:ok, %{url: url}} = Storage.put_url(key, %{content_type: "video/mp4", size: 5})
      tampered = String.replace(url, "len=5", "len=6")

      conn = conn |> put_req_header("content-type", "video/mp4") |> put(tampered, "hello")

      assert response(conn, 403) =~ "isn't valid"
    end

    test "fails if the type differs", %{conn: conn, key: key} do
      {:ok, %{url: url}} = Storage.put_url(key, %{content_type: "video/mp4", size: 5})

      conn = conn |> put_req_header("content-type", "image/png") |> put(url, "hello")

      assert response(conn, 400) == "type_mismatch"
    end

    test "fails if the size differs", %{conn: conn, key: key} do
      {:ok, %{url: url}} = Storage.put_url(key, %{content_type: "video/mp4", size: 9})

      conn = conn |> put_req_header("content-type", "video/mp4") |> put(url, "hello")

      assert response(conn, 400) == "size_mismatch"
      assert {:error, :not_found} = Storage.head(key)
    end

    test "upload", %{conn: conn, key: key} do
      {:ok, %{url: url}} = Storage.put_url(key, %{content_type: "video/mp4", size: 5})

      conn = conn |> put_req_header("content-type", "video/mp4") |> put(url, "hello")

      assert response(conn, 200) == ""
      assert {:ok, %{size: 5, content_type: "video/mp4"}} = Storage.head(key)
    end

    test "upload a part", %{conn: conn, key: key} do
      {:ok, upload_id} = Storage.start_multipart(key, "video/mp4")
      {:ok, url} = Storage.part_url(key, upload_id, 1)

      conn = conn |> put_req_header("content-type", "video/mp4") |> put(url, "part one")

      assert response(conn, 200) == ""
      assert {:ok, [%{number: 1, size: 8}]} = Storage.list_parts(key, upload_id)
    end
  end

  describe "GET" do
    test "fails if nothing is stored", %{conn: conn, key: key} do
      {:ok, url} = Storage.get_url(key)

      assert conn |> get(url) |> response(404)
    end

    test "never lets a file run as a page", %{conn: conn, key: key} do
      :ok = Storage.put(key, "<script>alert(1)</script>", "text/html")
      {:ok, url} = Storage.get_url(key)

      conn = get(conn, url)

      assert response(conn, 200)
      assert ["attachment"] = get_resp_header(conn, "content-disposition")
      assert ["nosniff"] = get_resp_header(conn, "x-content-type-options")
      assert ["default-src 'none'; sandbox"] = get_resp_header(conn, "content-security-policy")
    end

    test "sends a download under its name", %{conn: conn, key: key} do
      :ok = Storage.put(key, "hello world", "video/mp4")
      {:ok, url} = Storage.download_url(key, "Studio.mp4")

      conn = get(conn, url)

      assert response(conn, 200) == "hello world"

      assert [~s(attachment; filename="Studio.mp4"; filename*=UTF-8''Studio.mp4)] =
               get_resp_header(conn, "content-disposition")
    end

    test "reads a file", %{conn: conn, key: key} do
      :ok = Storage.put(key, "hello world", "video/mp4")
      {:ok, url} = Storage.get_url(key)

      conn = get(conn, url)

      assert response(conn, 200) == "hello world"
      assert ["video/mp4"] = get_resp_header(conn, "content-type")
    end

    test "reads a range", %{conn: conn, key: key} do
      :ok = Storage.put(key, "hello world", "video/mp4")
      {:ok, url} = Storage.get_url(key)

      conn = conn |> put_req_header("range", "bytes=6-") |> get(url)

      assert response(conn, 206) == "world"
      assert ["bytes 6-10/11"] = get_resp_header(conn, "content-range")
    end

    test "refuses a range past the end", %{conn: conn, key: key} do
      :ok = Storage.put(key, "hello", "video/mp4")
      {:ok, url} = Storage.get_url(key)

      conn = conn |> put_req_header("range", "bytes=10-20") |> get(url)

      assert response(conn, 416)
    end
  end

  describe "OPTIONS" do
    test "answers the browser's CORS check", %{conn: conn, key: key} do
      conn = options(conn, "/storage/" <> key)

      assert response(conn, 204)
      assert ["http://localhost:5173"] = get_resp_header(conn, "access-control-allow-origin")
      assert ["etag, content-range"] = get_resp_header(conn, "access-control-expose-headers")
    end
  end
end
