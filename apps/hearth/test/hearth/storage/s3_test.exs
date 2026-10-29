defmodule Hearth.Storage.S3Test do
  use ExUnit.Case, async: true

  import Req.Test

  alias Hearth.Storage.Object
  alias Hearth.Storage.S3
  alias Plug.Conn

  @path "/hearth-test/media/x/original"

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  describe "put_url/3" do
    test "signs type size and checksum" do
      digest = :crypto.hash(:sha256, "hello")
      sha = Base.encode16(digest, case: :lower)

      assert {:ok, %{url: url, headers: headers}} =
               S3.put_url(
                 "media/x/original",
                 %{content_type: "image/png", size: 5, sha256: sha},
                 600
               )

      assert %{"content-type" => "image/png", "content-length" => "5"} = headers
      assert headers["x-amz-checksum-sha256"] == Base.encode64(digest)

      %URI{query: query} = URI.parse(url)
      signed = URI.decode_query(query)["X-Amz-SignedHeaders"]

      assert signed =~ "content-length"
      assert signed =~ "content-type"
      assert signed =~ "x-amz-checksum-sha256"
    end
  end

  describe "get_url/4" do
    test "is the same for the same signing time" do
      hour = ~U[2026-10-25 11:00:00Z]

      assert S3.get_url("media/x/w640.webp", hour, 7_200, nil) ==
               S3.get_url("media/x/w640.webp", hour, 7_200, nil)
    end

    test "signs download under its name" do
      url = S3.get_url("media/x/original", ~U[2026-10-25 11:00:00Z], 7_200, "Talk.mp4")
      query = url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()

      assert query["response-content-disposition"] ==
               ~s(attachment; filename="Talk.mp4"; filename*=UTF-8''Talk.mp4)
    end
  end

  describe "head/1" do
    test "fails if nothing is stored" do
      stub(S3, fn %Conn{method: "HEAD", request_path: @path} = conn ->
        Conn.send_resp(conn, 404, "")
      end)

      assert {:error, :not_found} = S3.head("media/x/original")
    end

    test "head" do
      stub(S3, fn %Conn{method: "HEAD", request_path: @path} = conn ->
        conn
        |> Conn.put_resp_header("content-length", "2048")
        |> Conn.put_resp_header("content-type", "image/png")
        |> Conn.put_resp_header("etag", ~s("abc123"))
        |> Conn.send_resp(200, "")
      end)

      assert {:ok, %Object{size: 2048, content_type: "image/png", etag: "abc123"}} =
               S3.head("media/x/original")
    end
  end

  describe "start_multipart/2" do
    test "start multipart" do
      stub(S3, fn %Conn{method: "POST", request_path: @path, query_string: "uploads=1"} = conn ->
        Conn.send_resp(conn, 200, """
        <InitiateMultipartUploadResult>
          <Bucket>hearth-test</Bucket><Key>media/x/original</Key><UploadId>up-1</UploadId>
        </InitiateMultipartUploadResult>
        """)
      end)

      assert {:ok, "up-1"} = S3.start_multipart("media/x/original", "video/mp4")
    end
  end

  describe "part_url/4" do
    test "signs the part and upload" do
      assert {:ok, url} = S3.part_url("media/x/original", "up-1", 3, 600)

      assert %{"partNumber" => "3", "uploadId" => "up-1"} =
               url |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query()
    end
  end

  describe "list_parts/2" do
    test "list parts" do
      stub(S3, fn %Conn{method: "GET", request_path: @path, query_string: "uploadId=up-1"} = conn ->
        Conn.send_resp(conn, 200, """
        <ListPartsResult>
          <Part><PartNumber>1</PartNumber><ETag>"e1"</ETag><Size>10485760</Size></Part>
          <Part><PartNumber>2</PartNumber><ETag>"e2"</ETag><Size>42</Size></Part>
        </ListPartsResult>
        """)
      end)

      assert {:ok, [%{number: 1, etag: "e1", size: 10_485_760} | _parts]} =
               S3.list_parts("media/x/original", "up-1")
    end
  end

  describe "complete_multipart/3" do
    test "fails if the store refuses" do
      stub(S3, fn %Conn{method: "POST", request_path: @path, query_string: "uploadId=up-1"} = conn ->
        Conn.send_resp(conn, 400, "<Error><Code>InvalidPart</Code></Error>")
      end)

      assert {:error, {:http_error, 400, _response}} =
               S3.complete_multipart("media/x/original", "up-1", [{1, "e1"}])
    end

    test "complete multipart" do
      parts = "<Part><PartNumber>1</PartNumber><ETag>e1</ETag></Part>"

      stub(S3, fn %Conn{method: "POST", request_path: @path, query_string: "uploadId=up-1"} = conn ->
        {:ok, "<CompleteMultipartUpload>" <> ^parts <> "</CompleteMultipartUpload>", conn} =
          Conn.read_body(conn)

        Conn.send_resp(conn, 200, "<CompleteMultipartUploadResult/>")
      end)

      assert :ok = S3.complete_multipart("media/x/original", "up-1", [{1, "e1"}])
    end
  end
end
