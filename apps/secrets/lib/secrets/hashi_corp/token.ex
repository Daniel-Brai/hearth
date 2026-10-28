defmodule Secrets.HashiCorp.Token do
  @derive {Inspect, except: [:client_token]}

  @fields [:client_token, :lease_duration]

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{client_token: String.t(), lease_duration: non_neg_integer()}

  @spec from!(map()) :: no_return() | t()
  def from!(%{} = data) do
    %{"auth" => %{"client_token" => client_token, "lease_duration" => lease_duration}} = data

    %__MODULE__{client_token: client_token, lease_duration: lease_duration}
  end
end
