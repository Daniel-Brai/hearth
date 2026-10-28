defmodule Hearth.Common.Link do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset

  @fields [:url, :label]

  @primary_key false

  embedded_schema do
    field :url, :string
    field :label, :string
  end

  @type t :: %__MODULE__{url: String.t(), label: nil | String.t()}

  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = link, %{} = params) do
    link
    |> cast(params, @fields)
    |> validate_required(@fields -- [:label])
    |> validate_length(:url, max: 2_000)
    |> validate_length(:label, max: 40)
    |> validate_change(:url, &web_address/2)
  end

  @spec unique(map()) :: map()
  def unique(%{} = params) do
    Enum.reduce([:links, "links"], params, fn key, params ->
      case params do
        %{^key => links} when is_list(links) -> %{params | key => Enum.uniq_by(links, &url/1)}
        _params -> params
      end
    end)
  end

  defp url(%{url: url}), do: url
  defp url(%{"url" => url}), do: url
  defp url(_link), do: nil

  defp web_address(:url, url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ~w[http https] and host not in [nil, ""] ->
        []

      _other ->
        [url: "must be a web address"]
    end
  end
end
