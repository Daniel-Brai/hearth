defmodule HearthWeb.Rules do
  alias Hearth.Common
  alias Hearth.Communities
  alias Request.Validator.Rules

  def uuid do
    fn attr, value ->
      case Common.valid_id?(value) do
        true -> :ok
        false -> {:error, "The #{attr} field must be a valid id."}
      end
    end
  end

  def template, do: Rules.allowed(Communities.template_ids())

  # Like required, but an empty list still counts as sent
  def present do
    %{
      implicit?: true,
      validator: fn attr, value ->
        case value do
          nil -> {:error, "The #{attr} field is required."}
          _value -> :ok
        end
      end
    }
  end

  # Query values arrive as text, so a number can come either way
  def between(min, max) do
    fn attr, value ->
      case to_integer(value) do
        number when is_integer(number) and number >= min and number <= max -> :ok
        _other -> {:error, "The #{attr} field must be a whole number from #{min} to #{max}."}
      end
    end
  end

  defp to_integer(value) when is_integer(value), do: value

  defp to_integer(value) when is_binary(value) do
    case Integer.parse(value) do
      {number, ""} -> number
      _other -> nil
    end
  end

  defp to_integer(_value), do: nil
end
