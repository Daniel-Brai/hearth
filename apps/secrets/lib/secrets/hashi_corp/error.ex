defmodule Secrets.HashiCorp.Error do
  defexception ~w[status path errors]a

  @type t :: %__MODULE__{status: pos_integer(), path: nil | String.t(), errors: [String.t()]}

  @spec from!(map()) :: no_return() | t()
  def from!(%{} = data) do
    %{"status" => status} = data

    %__MODULE__{status: status, path: data["path"], errors: data["errors"] || []}
  end

  @impl Exception
  def message(%__MODULE__{status: status, path: path, errors: errors}) do
    what = if path, do: "reading #{path}", else: "signing in"

    "Vault answered #{status} #{what}" <>
      if(errors == [], do: "", else: ": " <> Enum.join(errors, "; "))
  end
end
