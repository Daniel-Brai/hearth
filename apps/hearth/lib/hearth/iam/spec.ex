defmodule Hearth.IAM.Spec do
  @rules_key {__MODULE__, :rules}

  @type rule :: %{
          permission: String.t(),
          roles: [String.t()],
          author: boolean(),
          scope: :community | :instance
        }

  @spec cache() :: :ok
  def cache do
    rules()

    :ok
  end

  @spec rules() :: %{String.t() => rule()}
  def rules do
    case :persistent_term.get(@rules_key, nil) do
      nil -> store(load())
      rules -> rules
    end
  end

  @spec rule(String.t()) :: nil | rule()
  def rule(permission) when is_binary(permission), do: Map.get(rules(), permission)

  @spec permissions(:community | :instance) :: [String.t()]
  def permissions(scope) do
    for {permission, %{scope: ^scope}} <- rules(), do: permission
  end

  @spec permissions_for(String.t()) :: [String.t()]
  def permissions_for(role) when is_binary(role) do
    for {permission, %{roles: roles}} <- rules(), role in roles, do: permission
  end

  @doc """
  The permission string for an operation on a resource

  ## Example

      iex> Hearth.IAM.Spec.permission(:"voice.session", :create)
      "voice-session.create"
  """
  @spec permission(atom() | String.t(), atom() | String.t()) :: String.t()
  def permission(resource, operation) do
    resource =
      resource
      |> to_string()
      |> String.replace(".", "-")

    "#{resource}.#{operation}"
  end

  defp store(rules) do
    :persistent_term.put(@rules_key, rules)
    rules
  end

  defp load do
    :hearth
    |> Application.app_dir(~w[priv permissions.yml])
    |> YamlElixir.read_from_file!()
    |> Map.new(fn entry ->
      %{"resource" => resource, "operation" => operation, "roles" => roles} = entry
      permission = permission(resource, operation)

      rule = %{
        permission: permission,
        roles: roles,
        author: Map.get(entry, "author", false),
        scope: scope(Map.get(entry, "scope", "community"))
      }

      {permission, rule}
    end)
  end

  defp scope("community"), do: :community
  defp scope("instance"), do: :instance
end
