defmodule Hearth.StorageTest do
  use ExUnit.Case, async: true

  alias Hearth.Common
  alias Hearth.Storage
  alias Hearth.Storage.Object

  setup do
    {:ok, key: "test/#{Common.new_id()}/file.txt"}
  end

  describe "valid_key?/1" do
    test "fails if a key could leave its folder" do
      refute Storage.valid_key?("../etc/passwd")
      refute Storage.valid_key?("media//x")
      refute Storage.valid_key?("/absolute")
      refute Storage.valid_key?("Media/Upper")
      refute Storage.valid_key?("")
    end

    test "accepts media keys" do
      assert Storage.valid_key?("media/0199b2c4-77aa-7c1e-9f3b-1f2e3d4c5b6a/w640.webp")
    end
  end

  describe "put/3 and head/1" do
    test "fails if the key is invalid" do
      assert {:error, :invalid_key} = Storage.put("../x", "hi", "text/plain")
    end

    test "fails if nothing is stored", %{key: key} do
      assert {:error, :not_found} = Storage.head(key)
    end

    test "put and head", %{key: key} do
      assert :ok = Storage.put(key, "hello", "text/plain")

      assert {:ok, %Object{size: 5, content_type: "text/plain", etag: etag}} = Storage.head(key)
      md5 = :crypto.hash(:md5, "hello")
      assert etag == Base.encode16(md5, case: :lower)
    end
  end

  describe "upload_file/3 and download/2" do
    test "fails if nothing is stored", %{key: key} do
      assert {:error, :not_found} = Storage.download(key, Path.join(System.tmp_dir!(), "none"))
    end

    test "upload and download", %{key: key} do
      source = Path.join(System.tmp_dir!(), "hearth-source-#{System.unique_integer([:positive])}")
      target = source <> ".copy"
      File.write!(source, String.duplicate("x", 1_000))

      assert :ok = Storage.upload_file(key, source, "text/plain")
      assert :ok = Storage.download(key, target)
      assert File.read!(target) == File.read!(source)
    end
  end

  describe "delete/1 and delete_prefix/1" do
    test "delete prefix", %{key: key} do
      prefix = Path.dirname(key)
      :ok = Storage.put(prefix <> "/a.webp", "a", "image/webp")
      :ok = Storage.put(prefix <> "/b.webp", "b", "image/webp")

      assert :ok = Storage.delete_prefix(prefix)
      assert {:error, :not_found} = Storage.head(prefix <> "/a.webp")
    end

    test "delete", %{key: key} do
      :ok = Storage.put(key, "hello", "text/plain")

      assert :ok = Storage.delete(key)
      assert {:error, :not_found} = Storage.head(key)
    end
  end

  describe "put_url/2" do
    test "fails if the key is invalid" do
      assert {:error, :invalid_key} =
               Storage.put_url("a/../b", %{content_type: "image/png", size: 1})
    end

    test "signs type size and checksum", %{key: key} do
      digest = :crypto.hash(:sha256, "hello")
      sha = Base.encode16(digest, case: :lower)

      assert {:ok, %{url: url, headers: %{"content-type" => "text/plain"}}} =
               Storage.put_url(key, %{content_type: "text/plain", size: 5, sha256: sha})

      %URI{path: "/storage/" <> ^key, query: query} = URI.parse(url)
      params = URI.decode_query(query)

      assert {:ok, %{"ct" => "text/plain", "len" => "5", "sha" => ^sha}} =
               Storage.verify_local("PUT", key, params)

      assert {:error, :invalid} = Storage.verify_local("PUT", key, %{params | "len" => "6"})
      assert {:error, :invalid} = Storage.verify_local("GET", key, params)
      assert {:error, :invalid} = Storage.verify_local("PUT", key <> "x", params)
    end
  end

  describe "get_url/1" do
    test "keeps the same URL within the hour", %{key: key} do
      assert {:ok, url} = Storage.get_url(key)
      assert {:ok, ^url} = Storage.get_url(key)

      params = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      assert {:ok, %{"op" => "get"}} = Storage.verify_local("GET", key, params)
    end

    test "fails once expired", %{key: key} do
      {:ok, url} = Storage.get_url(key)
      params = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
      expired = %{params | "exp" => "1"}

      assert {:error, :invalid} = Storage.verify_local("GET", key, expired)
    end
  end

  describe "download_url/2" do
    test "fails if the name is changed", %{key: key} do
      {:ok, url} = Storage.download_url(key, "notes.pdf")
      params = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      assert {:error, :invalid} = Storage.verify_local("GET", key, %{params | "dl" => "x.html"})
    end

    test "signs the name to save under", %{key: key} do
      {:ok, url} = Storage.download_url(key, "notes.pdf")
      params = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      assert {:ok, %{"dl" => "notes.pdf"}} = Storage.verify_local("GET", key, params)
    end
  end

  describe "disposition/1" do
    test "keeps quotes and other characters out of the plain name" do
      assert Storage.disposition(~s(Café "night".mp4)) ==
               ~s(attachment; filename="Caf_ _night_.mp4"; filename*=UTF-8''Caf%C3%A9%20%22night%22.mp4)
    end
  end

  describe "write_local/3" do
    test "fails if size or checksum differ", %{key: key} do
      assert {:error, :size_mismatch} = Storage.write_local(key, ["hello"], %{size: 6})

      assert {:error, :checksum_mismatch} =
               Storage.write_local(key, ["hello"], %{size: 5, sha256: String.duplicate("0", 64)})

      assert {:error, :not_found} = Storage.head(key)
    end
  end

  describe "multipart" do
    test "fails to complete with parts it doesn't have", %{key: key} do
      {:ok, upload_id} = Storage.start_multipart(key, "video/mp4")
      {:ok, _etag} = Storage.write_local_part(key, upload_id, 1, ["part one"])

      assert {:error, :invalid_parts} = Storage.complete_multipart(key, upload_id, [{1, "nope"}])
    end

    test "fails to write a part for another key", %{key: key} do
      {:ok, upload_id} = Storage.start_multipart(key, "video/mp4")

      assert {:error, :not_found} = Storage.write_local_part(key <> "x", upload_id, 1, ["x"])
    end

    test "upload in parts", %{key: key} do
      {:ok, upload_id} = Storage.start_multipart(key, "video/mp4")
      assert {:ok, url} = Storage.part_url(key, upload_id, 2)
      assert url =~ "op=part"

      {:ok, first} = Storage.write_local_part(key, upload_id, 1, ["one "])
      {:ok, second} = Storage.write_local_part(key, upload_id, 2, ["two"])

      assert {:ok, [%{number: 1, etag: ^first, size: 4}, %{number: 2, etag: ^second}]} =
               Storage.list_parts(key, upload_id)

      assert :ok = Storage.complete_multipart(key, upload_id, [{1, first}, {2, second}])
      assert {:ok, %Object{size: 7, content_type: "video/mp4", etag: etag}} = Storage.head(key)
      assert String.ends_with?(etag, "-2")
    end

    test "abort", %{key: key} do
      {:ok, upload_id} = Storage.start_multipart(key, "video/mp4")

      assert :ok = Storage.abort_multipart(key, upload_id)
      assert {:error, :not_found} = Storage.list_parts(key, upload_id)
    end
  end
end
