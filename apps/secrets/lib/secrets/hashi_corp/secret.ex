defmodule Secrets.HashiCorp.Secret do
  @derive {Inspect, except: [:data]}

  @fields [:data, :version]

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{data: %{optional(String.t()) => term()}, version: pos_integer()}

  @spec from!(map()) :: no_return() | t()
  def from!(%{} = body) do
    %{"data" => %{"data" => data, "metadata" => %{"version" => version}}} = body

    %__MODULE__{data: data || %{}, version: version}
  end
end
