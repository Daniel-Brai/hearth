defmodule Hearth.Repo do
  use Boundary,
    deps: [Hearth.Common],
    exports: [Changeset, Flop, Page, Schema, Tree]

  use Ecto.Repo,
    otp_app: :hearth,
    adapter: Ecto.Adapters.Postgres

  @spec ping(pos_integer()) :: :ok | {:error, term()}
  def ping(timeout) do
    case query("SELECT 1", [], timeout: timeout, log: false) do
      {:ok, %{rows: [[1]]}} -> :ok
      {:error, reason} -> {:error, reason}
    end
  rescue
    error in DBConnection.ConnectionError -> {:error, error}
  end
end
