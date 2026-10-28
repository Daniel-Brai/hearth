defmodule Hearth.Storage.S3 do
  @behaviour Hearth.Storage.Adapter

  alias ExAws.Config
  alias ExAws.S3
  alias ExAws.S3.Upload
  alias Hearth.Storage
  alias Hearth.Storage.Object

  @req_options Application.compile_env(:hearth, [Storage, :req_options], [])

  @impl Hearth.Storage.Adapter
  def put_url(key, %{content_type: type, size: size} = upload, expires_in) do
    base = [{"content-type", type}, {"content-length", Integer.to_string(size)}]
    headers = with_checksum(base, upload[:sha256])

    {:ok, url} =
      S3.presigned_url(config(), :put, bucket(), key,
        expires_in: expires_in,
        headers: headers,
        virtual_host: virtual_host?()
      )

    {:ok, %{url: url, headers: Map.new(headers)}}
  end

  @impl Hearth.Storage.Adapter
  def get_url(key, signed_at, expires_in, download) do
    {:ok, url} =
      S3.presigned_url(config(), :get, bucket(), key,
        expires_in: expires_in,
        start_datetime: DateTime.to_naive(signed_at),
        virtual_host: virtual_host?(),
        query_params: download_params(download)
      )

    url
  end

  defp download_params(nil), do: []

  defp download_params(filename),
    do: [{"response-content-disposition", Storage.disposition(filename)}]

  @impl Hearth.Storage.Adapter
  def head(key) do
    case request(S3.head_object(bucket(), key)) do
      {:ok, %{headers: headers}} ->
        headers = Map.new(headers, fn {name, value} -> {String.downcase(name), value} end)

        {:ok,
         %Object{
           key: key,
           size: String.to_integer(headers["content-length"] || "0"),
           content_type: headers["content-type"],
           etag: unquote_etag(headers["etag"])
         }}

      {:error, {:http_error, 404, _response}} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Hearth.Storage.Adapter
  def put(key, data, content_type) do
    bucket()
    |> S3.put_object(key, data, content_type: content_type)
    |> request()
    |> ok()
  end

  @impl Hearth.Storage.Adapter
  def delete(key) do
    bucket()
    |> S3.delete_object(key)
    |> request()
    |> ok()
  end

  @impl Hearth.Storage.Adapter
  def delete_prefix(prefix) do
    bucket()
    |> S3.list_objects_v2(prefix: prefix)
    |> ExAws.stream!(overrides())
    |> Stream.map(& &1.key)
    |> Stream.chunk_every(1_000)
    |> Enum.each(fn keys ->
      bucket()
      |> S3.delete_multiple_objects(keys)
      |> request()
      |> ok()
    end)
  end

  @impl Hearth.Storage.Adapter
  def upload_file(key, path, content_type) do
    path
    |> Upload.stream_file(chunk_size: Storage.part_size())
    |> S3.upload(bucket(), key, content_type: content_type)
    |> request()
    |> ok()
  end

  @impl Hearth.Storage.Adapter
  def download(key, path) do
    case request(S3.download_file(bucket(), key, path)) do
      {:ok, :done} -> :ok
      {:error, {:http_error, 404, _response}} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Hearth.Storage.Adapter
  def start_multipart(key, content_type) do
    case request(S3.initiate_multipart_upload(bucket(), key, content_type: content_type)) do
      {:ok, %{body: %{upload_id: upload_id}}} -> {:ok, upload_id}
      {:error, reason} -> {:error, reason}
    end
  end

  @impl Hearth.Storage.Adapter
  def part_url(key, upload_id, number, expires_in) do
    S3.presigned_url(config(), :put, bucket(), key,
      expires_in: expires_in,
      query_params: [{"partNumber", Integer.to_string(number)}, {"uploadId", upload_id}],
      virtual_host: virtual_host?()
    )
  end

  @impl Hearth.Storage.Adapter
  def list_parts(key, upload_id) do
    case request(S3.list_parts(bucket(), key, upload_id)) do
      {:ok, %{body: %{parts: parts}}} ->
        {:ok,
         Enum.map(parts, fn part ->
           %{
             number: String.to_integer(part.part_number),
             etag: unquote_etag(part.etag),
             size: String.to_integer(part.size)
           }
         end)}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Hearth.Storage.Adapter
  def complete_multipart(key, upload_id, parts) do
    bucket()
    |> S3.complete_multipart_upload(key, upload_id, parts)
    |> request()
    |> ok()
  end

  @impl Hearth.Storage.Adapter
  def abort_multipart(key, upload_id) do
    bucket()
    |> S3.abort_multipart_upload(key, upload_id)
    |> request()
    |> ok()
  end

  # S3 wants the checksum as base64 of the digest, and clients send it as hex
  defp with_checksum(headers, sha256) when is_binary(sha256) do
    with true <- settings()[:checksums],
         {:ok, digest} <- Base.decode16(sha256, case: :mixed) do
      [{"x-amz-checksum-sha256", Base.encode64(digest)} | headers]
    else
      _skip -> headers
    end
  end

  defp with_checksum(headers, _sha256), do: headers

  defp unquote_etag(nil), do: nil
  defp unquote_etag(etag), do: String.trim(etag, "\"")

  defp ok({:ok, _response}), do: :ok
  defp ok({:error, reason}), do: {:error, reason}

  defp request(operation), do: ExAws.request(operation, overrides())

  defp bucket, do: settings()[:bucket]
  defp virtual_host?, do: not settings()[:path_style]

  defp config, do: Config.new(:s3, overrides())

  defp overrides do
    settings = settings()
    endpoint = URI.parse(settings[:endpoint])

    [
      access_key_id: settings[:access_key_id],
      secret_access_key: settings[:secret_access_key],
      region: settings[:region],
      scheme: endpoint.scheme <> "://",
      host: endpoint.host,
      port: endpoint.port,
      http_opts: @req_options
    ]
  end

  defp settings, do: Application.fetch_env!(:hearth, Storage)
end
