defmodule HearthWeb.ErrorJSON do
  alias Ecto.Changeset
  alias Phoenix.Controller

  def render(template, assigns) do
    message = assigns[:message] || Controller.status_message_from_template(template)

    case assigns do
      %{changeset: changeset} -> %{message: message, errors: errors_on(changeset)}
      %{errors: errors} -> %{message: message, errors: errors}
      %{code: code} -> %{message: message, code: code}
      _assigns -> %{message: message}
    end
  end

  @spec errors_on(Changeset.t()) :: %{String.t() => [String.t()]}
  def errors_on(%Changeset{} = changeset) do
    changeset
    |> Changeset.traverse_errors(fn {message, opts} ->
      Enum.reduce(opts, message, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
    |> flatten("")
  end

  defp flatten(errors, prefix) do
    Enum.reduce(errors, %{}, fn {field, value}, acc ->
      key = prefix <> to_string(field)

      case value do
        [message | _rest] when is_binary(message) -> Map.put(acc, key, value)
        %{} = nested -> Map.merge(acc, flatten(nested, key <> "."))
        list when is_list(list) -> Map.merge(acc, flatten_list(list, key <> "."))
      end
    end)
  end

  defp flatten_list(list, prefix) do
    list
    |> Enum.with_index()
    |> Enum.reject(fn {errors, _index} -> errors == %{} end)
    |> Enum.reduce(%{}, fn {errors, index}, acc ->
      Map.merge(acc, flatten(errors, prefix <> "#{index}."))
    end)
  end
end
