defmodule Hearth.Storage.Local do
  # Paths come only from checked keys and ids made here so Sobelow's traversal warnings are skipped

  @behaviour Hearth.Storage.Adapter

  alias Hearth.Storage
  alias Hearth.Storage.Object

  @impl Hearth.Storage.Adapter
  def put_url(key, %{content_type: type, size: size} = upload, expires_in) do
    params = %{
      "op" => "put",
      "ct" => type,
      "len" => Integer.to_string(size),
      "sha" => upload[:sha256] || ""
    }

    {:ok, %{url: signed_url(key, params, expires_in), headers: %{"content-type" => type}}}
  end

  @impl Hearth.Storage.Adapter
  def get_url(key, signed_at, expires_in, download) do
    expires = DateTime.to_unix(signed_at) + expires_in

    %{"op" => "get", "exp" => Integer.to_string(expires)}
    |> put_download(download)
    |> then(&signed_params(key, &1))
    |> then(&url(key, &1))
  end

  defp put_download(params, nil), do: params
  defp put_download(params, filename), do: Map.put(params, "dl", filename)

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def head(key) do
    path = object_path(key)

    case File.stat(path) do
      {:ok, %File.Stat{size: size}} ->
        meta = read_meta(key)

        {:ok,
         %Object{key: key, size: size, content_type: meta["content_type"], etag: meta["etag"]}}

      {:error, :enoent} ->
        {:error, :not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @impl Hearth.Storage.Adapter
  def put(key, data, content_type) do
    with {:ok, _etag} <- write(key, [data], %{content_type: content_type}), do: :ok
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def delete(key) do
    for path <- [object_path(key), meta_path(key)], do: File.rm(path)

    :ok
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def delete_prefix(prefix) do
    meta = Path.join(root(), "meta/" <> prefix)

    for path <- [object_path(prefix), meta], do: File.rm_rf!(path)

    :ok
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def upload_file(key, path, content_type) do
    chunks = File.stream!(path, Storage.part_size())

    with {:ok, _etag} <- write(key, chunks, %{content_type: content_type}), do: :ok
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def download(key, path) do
    source = object_path(key)

    case File.cp(source, path) do
      :ok -> :ok
      {:error, :enoent} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def start_multipart(key, content_type) do
    upload_id =
      18
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64(padding: false)

    dir = multipart_dir(upload_id)

    File.mkdir_p!(dir)

    info = JSON.encode!(%{key: key, content_type: content_type})
    dir |> Path.join("info.json") |> File.write!(info)

    {:ok, upload_id}
  end

  @impl Hearth.Storage.Adapter
  def part_url(key, upload_id, number, expires_in) do
    params = %{"op" => "part", "upload" => upload_id, "n" => Integer.to_string(number)}

    {:ok, signed_url(key, params, expires_in)}
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def list_parts(key, upload_id) do
    with {:ok, _info} <- upload_info(key, upload_id) do
      parts =
        upload_id
        |> multipart_dir()
        |> File.ls!()
        |> Enum.flat_map(&part(upload_id, &1))
        |> Enum.sort_by(& &1.number)

      {:ok, parts}
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def complete_multipart(key, upload_id, parts) do
    with {:ok, info} <- upload_info(key, upload_id),
         {:ok, stored} <- list_parts(key, upload_id),
         :ok <- same_parts(parts, stored) do
      dir = multipart_dir(upload_id)

      chunks =
        Stream.flat_map(parts, fn {number, _etag} ->
          File.stream!(Path.join(dir, "#{number}"), 65_536)
        end)

      etag = multipart_etag(stored)

      with {:ok, _md5} <- write(key, chunks, %{content_type: info["content_type"], etag: etag}) do
        File.rm_rf!(dir)
        :ok
      end
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  @impl Hearth.Storage.Adapter
  def abort_multipart(_key, upload_id) do
    upload_id
    |> multipart_dir()
    |> File.rm_rf!()

    :ok
  end

  @spec verify(String.t(), String.t(), map()) :: {:ok, map()} | {:error, :invalid | :expired}
  def verify(method, key, %{"sig" => sig, "exp" => exp, "op" => op} = params) do
    expected = sign(key, Map.delete(params, "sig"))

    with true <- Storage.valid_key?(key) and allowed?(method, op),
         true <- byte_size(sig) == byte_size(expected) and :crypto.hash_equals(sig, expected),
         {expires, ""} <- Integer.parse(exp),
         :ok <- unexpired(expires) do
      {:ok, params}
    else
      {:error, _reason} = error -> error
      _malformed -> {:error, :invalid}
    end
  end

  def verify(_method, _key, _params), do: {:error, :invalid}

  # The bytes go to a temp file first so a refused upload never replaces a stored one
  # sobelow_skip ["Traversal.FileModule"]
  @spec write(String.t(), Enumerable.t(), map()) ::
          {:ok, String.t()} | {:error, :size_mismatch | :checksum_mismatch}
  def write(key, chunks, expected) do
    temp = Path.join(root(), "tmp/#{System.unique_integer([:positive])}")
    temp |> Path.dirname() |> File.mkdir_p!()

    {size, md5, sha} = stream_to(temp, chunks)

    with :ok <- check(:size, expected[:size], size),
         :ok <- check(:sha256, expected[:sha256], Base.encode16(sha, case: :lower)) do
      etag = expected[:etag] || Base.encode16(md5, case: :lower)
      target = object_path(key)
      target |> Path.dirname() |> File.mkdir_p!()
      File.rename!(temp, target)
      write_meta(key, %{content_type: expected[:content_type], etag: etag})

      {:ok, etag}
    else
      error ->
        File.rm(temp)
        error
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  @spec write_part(String.t(), String.t(), pos_integer(), Enumerable.t()) ::
          {:ok, String.t()} | {:error, :not_found}
  def write_part(key, upload_id, number, chunks) do
    with {:ok, _info} <- upload_info(key, upload_id) do
      path = upload_id |> multipart_dir() |> Path.join("#{number}")
      {_size, md5, _sha} = stream_to(path, chunks)

      {:ok, Base.encode16(md5, case: :lower)}
    end
  end

  @spec object_path(String.t()) :: Path.t()
  def object_path(key), do: Path.join(root(), "objects/" <> key)

  # sobelow_skip ["Traversal.FileModule"]
  defp stream_to(path, chunks) do
    init = {0, :crypto.hash_init(:md5), :crypto.hash_init(:sha256)}

    {size, md5, sha} =
      File.open!(path, [:write, :binary], fn file ->
        Enum.reduce(chunks, init, fn chunk, {size, md5, sha} ->
          IO.binwrite(file, chunk)

          {size + IO.iodata_length(chunk), :crypto.hash_update(md5, chunk),
           :crypto.hash_update(sha, chunk)}
        end)
      end)

    {size, :crypto.hash_final(md5), :crypto.hash_final(sha)}
  end

  defp check(_what, nil, _actual), do: :ok
  defp check(_what, "", _actual), do: :ok
  defp check(:size, expected, expected), do: :ok
  defp check(:size, _expected, _actual), do: {:error, :size_mismatch}

  defp check(:sha256, expected, actual) do
    case String.downcase(expected) == actual do
      true -> :ok
      false -> {:error, :checksum_mismatch}
    end
  end

  defp same_parts(parts, stored) do
    by_number = Map.new(stored, &{&1.number, &1.etag})

    case Enum.all?(parts, fn {number, etag} -> by_number[number] == String.trim(etag, "\"") end) do
      true -> :ok
      false -> {:error, :invalid_parts}
    end
  end

  defp multipart_etag(parts) do
    digests = Enum.map(parts, &Base.decode16!(&1.etag, case: :lower))
    digest = :crypto.hash(:md5, digests)
    Base.encode16(digest, case: :lower) <> "-#{length(parts)}"
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp part(upload_id, name) do
    case Integer.parse(name) do
      {number, ""} ->
        path = upload_id |> multipart_dir() |> Path.join(name)

        etag =
          path
          |> File.stream!(65_536)
          |> Enum.reduce(:crypto.hash_init(:md5), &:crypto.hash_update(&2, &1))
          |> :crypto.hash_final()
          |> Base.encode16(case: :lower)

        [%{number: number, etag: etag, size: File.stat!(path).size}]

      _info ->
        []
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp upload_info(key, upload_id) do
    info = upload_id |> multipart_dir() |> Path.join("info.json")

    with {:ok, json} <- File.read(info),
         %{"key" => ^key} = info <- JSON.decode!(json) do
      {:ok, info}
    else
      _missing -> {:error, :not_found}
    end
  end

  defp unexpired(expires) do
    case expires >= System.os_time(:second) do
      true -> :ok
      false -> {:error, :expired}
    end
  end

  defp allowed?("PUT", op), do: op in ~w[put part]
  defp allowed?(method, "get"), do: method in ~w[GET HEAD]
  defp allowed?(_method, _op), do: false

  defp signed_url(key, params, expires_in) do
    expires = System.os_time(:second) + expires_in
    params = Map.put(params, "exp", Integer.to_string(expires))

    url(key, signed_params(key, params))
  end

  defp signed_params(key, params), do: Map.put(params, "sig", sign(key, params))

  defp sign(key, params) do
    payload = [key | params |> Enum.sort() |> Enum.map(fn {k, v} -> [k, "=", v] end)]
    secret = Application.fetch_env!(:hearth, :secret_key_base)

    :hmac
    |> :crypto.mac(:sha256, secret, Enum.intersperse(payload, "\n"))
    |> Base.url_encode64(padding: false)
  end

  defp url(key, params),
    do: "#{settings()[:local_url]}/storage/#{key}?#{URI.encode_query(params)}"

  # sobelow_skip ["Traversal.FileModule"]
  defp read_meta(key) do
    path = meta_path(key)

    case File.read(path) do
      {:ok, json} -> JSON.decode!(json)
      {:error, _reason} -> %{}
    end
  end

  # sobelow_skip ["Traversal.FileModule"]
  defp write_meta(key, meta) do
    path = meta_path(key)
    path |> Path.dirname() |> File.mkdir_p!()
    File.write!(path, JSON.encode!(meta))
  end

  defp meta_path(key), do: Path.join(root(), "meta/" <> key <> ".json")
  defp multipart_dir(upload_id), do: Path.join(root(), "multipart/" <> upload_id)
  defp root, do: settings()[:local_root]
  defp settings, do: Application.fetch_env!(:hearth, Storage)
end
