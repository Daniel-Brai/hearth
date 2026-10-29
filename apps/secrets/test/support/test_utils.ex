defmodule Secrets.TestUtils do
  import ExUnit.Callbacks

  def put_env(key, value) do
    case Application.fetch_env(:secrets, key) do
      {:ok, previous} -> on_exit(fn -> Application.put_env(:secrets, key, previous) end)
      :error -> on_exit(fn -> Application.delete_env(:secrets, key) end)
    end

    Application.put_env(:secrets, key, value)
  end

  def merge_env(key, changes) do
    put_env(key, :secrets |> Application.fetch_env!(key) |> Keyword.merge(changes))
  end
end
