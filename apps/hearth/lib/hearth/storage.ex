defmodule Hearth.Storage do
  exports =
    case Mix.env() do
      :test -> [Object, S3]
      _env -> [Object]
    end

  use Boundary, deps: [Hearth.Common], exports: exports

  alias Hearth.Common
  alias Hearth.Storage.Adapter
  alias Hearth.Storage.Local
  alias Hearth.Storage.Object
  alias Hearth.Storage.S3

  @put_expires_in 600
  @get_expires_in 7_200
  @part_size 10 * 1024 * 1024

  @spec part_size() :: pos_integer()
  def part_size, do: @part_size

  @spec put_url(Adapter.key(), Adapter.upload()) ::
          {:ok, Adapter.signed()} | {:error, :invalid_key}
  def put_url(key, %{content_type: _, size: _} = upload) do
    with :ok <- check_key(key), do: adapter().put_url(key, upload, @put_expires_in)
  end

  # Signed at the start of the hour so the same file keeps one URL for caches
  @spec get_url(Adapter.key()) :: {:ok, String.t()} | {:error, :invalid_key}
  def get_url(key), do: signed_get(key, nil)

  @spec download_url(Adapter.key(), String.t()) :: {:ok, String.t()} | {:error, :invalid_key}
  def download_url(key, filename) when is_binary(filename), do: signed_get(key, filename)

  @spec disposition(String.t()) :: String.t()
  def disposition(filename) when is_binary(filename) do
    plain = String.replace(filename, ~r/[^\x20-\x7E]|["\\]/u, "_")

    ~s(attachment; filename="#{plain}"; filename*=UTF-8''#{URI.encode(filename, &URI.char_unreserved?/1)})
  end

  defp signed_get(key, download) do
    with :ok <- check_key(key) do
      now = DateTime.utc_now()
      hour = %{now | minute: 0, second: 0, microsecond: {0, 0}}

      {:ok, adapter().get_url(key, hour, @get_expires_in, download)}
    end
  end

  @spec head(Adapter.key()) :: {:ok, Object.t()} | {:error, :not_found | :invalid_key | term()}
  def head(key), do: with(:ok <- check_key(key), do: adapter().head(key))

  @spec put(Adapter.key(), iodata(), String.t()) :: :ok | {:error, term()}
  def put(key, data, content_type) do
    with :ok <- check_key(key) do
      Common.span("storage.put", %{key: key, bytes: IO.iodata_length(data)}, fn ->
        adapter().put(key, data, content_type)
      end)
    end
  end

  @spec delete(Adapter.key()) :: :ok | {:error, term()}
  def delete(key), do: with(:ok <- check_key(key), do: adapter().delete(key))

  @spec delete_prefix(String.t()) :: :ok | {:error, term()}
  def delete_prefix(prefix) do
    with :ok <- check_key(prefix) do
      Common.span("storage.delete_prefix", %{prefix: prefix}, fn ->
        adapter().delete_prefix(prefix)
      end)
    end
  end

  @spec upload_file(Adapter.key(), Path.t(), String.t()) :: :ok | {:error, term()}
  def upload_file(key, path, content_type) do
    with :ok <- check_key(key) do
      Common.span("storage.upload_file", %{key: key, bytes: file_size(path)}, fn ->
        adapter().upload_file(key, path, content_type)
      end)
    end
  end

  @spec download(Adapter.key(), Path.t()) :: :ok | {:error, :not_found | term()}
  def download(key, path) do
    with :ok <- check_key(key) do
      Common.span("storage.download", %{key: key}, fn -> adapter().download(key, path) end)
    end
  end

  @spec start_multipart(Adapter.key(), String.t()) :: {:ok, String.t()} | {:error, term()}
  def start_multipart(key, content_type) do
    with :ok <- check_key(key), do: adapter().start_multipart(key, content_type)
  end

  @spec part_url(Adapter.key(), String.t(), pos_integer()) ::
          {:ok, String.t()} | {:error, :invalid_key}
  def part_url(key, upload_id, number) when number in 1..10_000 do
    with :ok <- check_key(key), do: adapter().part_url(key, upload_id, number, @put_expires_in)
  end

  @spec list_parts(Adapter.key(), String.t()) :: {:ok, [Adapter.part()]} | {:error, term()}
  def list_parts(key, upload_id),
    do: with(:ok <- check_key(key), do: adapter().list_parts(key, upload_id))

  @spec complete_multipart(Adapter.key(), String.t(), [{pos_integer(), String.t()}]) ::
          :ok | {:error, term()}
  def complete_multipart(key, upload_id, parts) do
    with :ok <- check_key(key), do: adapter().complete_multipart(key, upload_id, parts)
  end

  @spec abort_multipart(Adapter.key(), String.t()) :: :ok | {:error, term()}
  def abort_multipart(key, upload_id) do
    with :ok <- check_key(key), do: adapter().abort_multipart(key, upload_id)
  end

  @spec local?() :: boolean()
  def local?, do: adapter() == Local

  @spec verify_local(String.t(), String.t(), map()) ::
          {:ok, map()} | {:error, :invalid | :expired}
  defdelegate verify_local(method, key, params), to: Local, as: :verify

  @spec write_local(String.t(), Enumerable.t(), map()) :: {:ok, String.t()} | {:error, atom()}
  defdelegate write_local(key, chunks, expected), to: Local, as: :write

  @spec write_local_part(String.t(), String.t(), pos_integer(), Enumerable.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  defdelegate write_local_part(key, upload_id, number, chunks), to: Local, as: :write_part

  @spec local_path(String.t()) :: Path.t()
  defdelegate local_path(key), to: Local, as: :object_path

  @spec valid_key?(term()) :: boolean()
  def valid_key?(key) when is_binary(key) and byte_size(key) in 1..512 do
    segments = String.split(key, "/")

    Enum.all?(segments, &(&1 not in ["", ".", ".."])) and
      key |> String.to_charlist() |> Enum.all?(&(&1 in ?a..?z or &1 in ?0..?9 or &1 in ~c"-_./"))
  end

  def valid_key?(_key), do: false

  defp file_size(path) do
    case File.stat(path) do
      {:ok, %File.Stat{size: size}} -> size
      {:error, _reason} -> 0
    end
  end

  defp check_key(key) do
    case valid_key?(key) do
      true -> :ok
      false -> {:error, :invalid_key}
    end
  end

  defp adapter do
    case Application.fetch_env!(:hearth, __MODULE__)[:adapter] do
      "s3" -> S3
      _local -> Local
    end
  end
end
