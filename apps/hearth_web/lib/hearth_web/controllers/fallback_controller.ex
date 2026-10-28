defmodule HearthWeb.FallbackController do
  use Phoenix.Controller, formats: [:json]

  alias Ecto.Changeset
  alias HearthWeb.ErrorJSON

  @statuses ~w[not_found forbidden unauthorized]a
  @templates %{not_found: :"404", forbidden: :"403", unauthorized: :"401"}

  def call(conn, {:error, %Changeset{} = changeset}) do
    conn
    |> put_status(:unprocessable_content)
    |> put_view(json: ErrorJSON)
    |> render(:"422", changeset: changeset)
  end

  def call(conn, {:error, reason}) when reason in @statuses do
    conn
    |> put_status(reason)
    |> put_view(json: ErrorJSON)
    |> render(@templates[reason], code: reason)
  end

  def call(conn, {:error, %Flop.Meta{}}) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ErrorJSON)
    |> render(:"400", code: :invalid_paging, message: "The page cursor or filter can't be used.")
  end

  def call(conn, {:error, :rate_limited}) do
    conn
    |> put_status(:too_many_requests)
    |> put_view(json: ErrorJSON)
    |> render(:"429", code: :rate_limited)
  end

  def call(conn, {:error, reason}) when is_atom(reason) do
    conn
    |> put_status(:bad_request)
    |> put_view(json: ErrorJSON)
    |> render(:"400", code: reason, message: message(reason))
  end

  defp message(reason) do
    reason
    |> Atom.to_string()
    |> String.replace("_", " ")
    |> String.capitalize()
    |> Kernel.<>(".")
  end
end
