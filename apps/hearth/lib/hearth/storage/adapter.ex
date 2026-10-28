defmodule Hearth.Storage.Adapter do
  alias Hearth.Storage.Object

  @type key :: String.t()
  @type upload :: %{
          required(:content_type) => String.t(),
          required(:size) => pos_integer(),
          optional(:sha256) => nil | String.t()
        }
  @type signed :: %{url: String.t(), headers: %{String.t() => String.t()}}
  @type part :: %{number: pos_integer(), etag: String.t(), size: non_neg_integer()}

  @callback put_url(key(), upload(), expires_in :: pos_integer()) :: {:ok, signed()}
  # With a file name the browser saves the file under it instead of showing it
  @callback get_url(
              key(),
              signed_at :: DateTime.t(),
              expires_in :: pos_integer(),
              download :: nil | String.t()
            ) :: String.t()
  @callback head(key()) :: {:ok, Object.t()} | {:error, :not_found | term()}
  @callback put(key(), iodata(), content_type :: String.t()) :: :ok | {:error, term()}
  @callback delete(key()) :: :ok | {:error, term()}
  @callback delete_prefix(prefix :: String.t()) :: :ok | {:error, term()}
  @callback upload_file(key(), path :: Path.t(), content_type :: String.t()) ::
              :ok | {:error, term()}
  @callback download(key(), path :: Path.t()) :: :ok | {:error, :not_found | term()}

  @callback start_multipart(key(), content_type :: String.t()) ::
              {:ok, String.t()} | {:error, term()}
  @callback part_url(key(), upload_id :: String.t(), pos_integer(), expires_in :: pos_integer()) ::
              {:ok, String.t()}
  @callback list_parts(key(), upload_id :: String.t()) :: {:ok, [part()]} | {:error, term()}
  @callback complete_multipart(key(), upload_id :: String.t(), [{pos_integer(), String.t()}]) ::
              :ok | {:error, term()}
  @callback abort_multipart(key(), upload_id :: String.t()) :: :ok | {:error, term()}
end
