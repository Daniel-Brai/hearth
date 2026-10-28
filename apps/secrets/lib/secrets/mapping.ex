defmodule Secrets.Mapping do
  @fields ~w[name path key optional]a

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          name: String.t(),
          path: String.t(),
          key: String.t(),
          optional: boolean()
        }

  @spec read!(Path.t(), String.t()) :: [t()]
  def read!(file, env) when is_binary(file) and is_binary(env) do
    mappings = YamlElixir.read_from_file!(file) || %{}

    mappings
    |> Enum.map(&from!(&1, env))
    |> Enum.sort_by(& &1.name)
  end

  defp from!({name, %{"path" => path, "key" => key} = entry}, env)
       when is_binary(path) and is_binary(key) do
    %__MODULE__{
      name: name,
      path: String.replace(path, "{env}", env),
      key: key,
      optional: entry["optional"] == true
    }
  end

  defp from!({name, _entry}, _env) do
    raise ArgumentError, "#{name} in the secrets file needs a path and a key"
  end
end
