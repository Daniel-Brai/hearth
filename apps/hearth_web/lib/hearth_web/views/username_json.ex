defmodule HearthWeb.UsernameJSON do
  def show(%{available: available}), do: %{available: available}
end
