defmodule HearthWeb.Plugs.LocalStorage do
  @behaviour Plug

  import Plug.Conn

  alias Hearth.Storage

  @read_length 1_048_576

  @impl Plug
  def init(opts), do: opts

  @impl Plug
  def call(%Plug.Conn{path_info: ["storage" | segments]} = conn, _opts) do
    case Storage.local?() do
      true ->
        conn
        |> fetch_query_params()
        |> cors()
        |> handle(Enum.join(segments, "/"))
        |> halt()

      false ->
        conn
    end
  end

  def call(conn, _opts), do: conn

  defp handle(%Plug.Conn{method: "OPTIONS"} = conn, _key), do: send_resp(conn, 204, "")

  defp handle(%Plug.Conn{method: method} = conn, key) when method in ~w[PUT GET HEAD] do
    case Storage.verify_local(method, key, conn.query_params) do
      {:ok, %{"op" => "put"} = params} -> put_file(conn, key, params)
      {:ok, %{"op" => "part"} = params} -> put_part(conn, key, params)
      {:ok, %{"op" => "get"} = params} -> get_file(conn, key, params["dl"])
      {:error, :expired} -> send_resp(conn, 403, "This link has expired")
      {:error, :invalid} -> send_resp(conn, 403, "This link isn't valid")
    end
  end

  defp handle(conn, _key), do: send_resp(conn, 405, "")

  # sobelow_skip ["Traversal.FileModule", "Traversal.SendFile", "XSS.ContentType"]
  defp put_file(conn, key, params) do
    with :ok <- same_type(conn, params["ct"]),
         {:ok, conn, temp} <- receive_body(conn) do
      expected = %{
        content_type: params["ct"],
        size: String.to_integer(params["len"]),
        sha256: params["sha"]
      }

      result = Storage.write_local(key, File.stream!(temp, 65_536), expected)
      File.rm(temp)

      case result do
        {:ok, etag} -> conn |> put_resp_header("etag", ~s("#{etag}")) |> send_resp(200, "")
        {:error, :size_mismatch} -> refuse(conn, "size_mismatch")
        {:error, :checksum_mismatch} -> refuse(conn, "checksum_mismatch")
      end
    else
      {:error, :type_mismatch} -> refuse(conn, "type_mismatch")
    end
  end

  # sobelow_skip ["Traversal.FileModule", "Traversal.SendFile", "XSS.ContentType"]
  defp put_part(conn, key, %{"upload" => upload_id, "n" => number}) do
    {:ok, conn, temp} = receive_body(conn)

    result =
      Storage.write_local_part(
        key,
        upload_id,
        String.to_integer(number),
        File.stream!(temp, 65_536)
      )

    File.rm(temp)

    case result do
      {:ok, etag} -> conn |> put_resp_header("etag", ~s("#{etag}")) |> send_resp(200, "")
      {:error, :not_found} -> send_resp(conn, 404, "")
    end
  end

  # sobelow_skip ["Traversal.FileModule", "Traversal.SendFile", "XSS.ContentType"]
  defp get_file(conn, key, download) do
    case Storage.head(key) do
      {:ok, object} ->
        type = object.content_type || "application/octet-stream"

        conn
        |> put_resp_content_type(type, nil)
        |> sandbox(type)
        |> attachment(download)
        |> put_resp_header("accept-ranges", "bytes")
        |> put_resp_header("etag", ~s("#{object.etag}"))
        |> send_range(Storage.local_path(key), object.size)

      {:error, _reason} ->
        send_resp(conn, 404, "")
    end
  end

  defp attachment(conn, nil), do: conn

  defp attachment(conn, filename),
    do: put_resp_header(conn, "content-disposition", Storage.disposition(filename))

  # sobelow_skip ["Traversal.FileModule", "Traversal.SendFile", "XSS.ContentType"]
  defp send_range(conn, path, size) do
    case parse_range(get_req_header(conn, "range"), size) do
      {first, last} ->
        conn
        |> put_resp_header("content-range", "bytes #{first}-#{last}/#{size}")
        |> send_file(206, path, first, last - first + 1)

      :all ->
        send_file(conn, 200, path)

      :unsatisfiable ->
        conn
        |> put_resp_header("content-range", "bytes */#{size}")
        |> send_resp(416, "")
    end
  end

  defp parse_range(["bytes=" <> spec], size) do
    case String.split(spec, "-", parts: 2) do
      [first, ""] -> to_range(Integer.parse(first), {size - 1, ""}, size)
      ["", suffix] -> suffix_range(Integer.parse(suffix), size)
      [first, last] -> to_range(Integer.parse(first), Integer.parse(last), size)
      _other -> :all
    end
  end

  defp parse_range(_header, _size), do: :all

  defp to_range({first, ""}, {last, ""}, size) when first <= last and first < size,
    do: {first, min(last, size - 1)}

  defp to_range(_first, _last, _size), do: :unsatisfiable

  defp suffix_range({count, ""}, size) when count > 0, do: {max(size - count, 0), size - 1}
  defp suffix_range(_suffix, _size), do: :unsatisfiable

  defp refuse(conn, reason) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(400, reason)
  end

  # Files share the API's origin so none may run as a page
  defp sandbox(conn, type) do
    conn =
      conn
      |> put_resp_header("x-content-type-options", "nosniff")
      |> put_resp_header("content-security-policy", "default-src 'none'; sandbox")

    case inline?(type) do
      true -> conn
      false -> put_resp_header(conn, "content-disposition", "attachment")
    end
  end

  defp inline?("image/svg+xml"), do: false
  defp inline?("application/pdf"), do: true

  defp inline?(type) do
    [kind | _rest] = String.split(type, "/")
    kind in ~w[image video audio]
  end

  defp same_type(conn, type) do
    case get_req_header(conn, "content-type") do
      [^type | _rest] -> :ok
      _other -> {:error, :type_mismatch}
    end
  end

  # sobelow_skip ["Traversal.FileModule", "Traversal.SendFile", "XSS.ContentType"]
  defp receive_body(conn) do
    temp = Path.join(System.tmp_dir!(), "hearth-upload-#{System.unique_integer([:positive])}")

    conn = File.open!(temp, [:write, :binary], &read_into(conn, &1))

    {:ok, conn, temp}
  end

  defp read_into(conn, file) do
    case read_body(conn, length: @read_length) do
      {:ok, data, conn} ->
        IO.binwrite(file, data)
        conn

      {:more, data, conn} ->
        IO.binwrite(file, data)
        read_into(conn, file)
    end
  end

  defp cors(conn) do
    conn
    |> put_resp_header(
      "access-control-allow-origin",
      Application.fetch_env!(:hearth, :public_url)
    )
    |> put_resp_header("access-control-allow-methods", "GET, PUT, HEAD, OPTIONS")
    |> put_resp_header(
      "access-control-allow-headers",
      "content-type, x-amz-checksum-sha256, range"
    )
    |> put_resp_header("access-control-expose-headers", "etag, content-range")
    |> put_resp_header("access-control-max-age", "3600")
  end
end
