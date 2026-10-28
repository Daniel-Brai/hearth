defmodule Secrets do
  @moduledoc "Nothing is set until every variable has been read so a failed boot never runs on half its secrets"

  use Boundary, deps: [], exports: []

  alias Secrets.HashiCorp
  alias Secrets.Mapping
  alias Secrets.MissingError

  require Logger

  @app :secrets

  @spec inject!() :: non_neg_integer()
  def inject! do
    settings = Confex.fetch_env!(@app, __MODULE__)

    case settings[:file] do
      nil -> 0
      file -> file |> Mapping.read!(settings[:env]) |> inject_all!()
    end
  end

  defp inject_all!([]), do: 0

  defp inject_all!(mappings) do
    token = HashiCorp.login!()

    secrets =
      mappings
      |> Enum.map(& &1.path)
      |> Enum.uniq()
      |> Map.new(&{&1, HashiCorp.read!(token, &1)})

    values = Enum.map(mappings, &{&1, value(secrets, &1)})

    case for {%Mapping{optional: false} = mapping, nil} <- values, do: mapping.name do
      [] -> :ok
      missing -> raise MissingError, names: missing
    end

    found = for {mapping, value} <- values, value != nil, do: {mapping.name, value}
    System.put_env(found)
    Logger.info("Set #{length(found)} variables from Vault")

    length(found)
  end

  defp value(secrets, %Mapping{path: path, key: key}) do
    case secrets[path].data do
      %{^key => value} when is_binary(value) and value != "" -> value
      _missing -> nil
    end
  end
end
