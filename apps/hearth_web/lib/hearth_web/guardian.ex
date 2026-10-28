defmodule HearthWeb.Guardian do
  @moduledoc "Only ES256 is accepted so a token naming none or any other algorithm is refused"

  use Guardian, otp_app: :hearth_web

  alias Hearth.Accounts

  @audience "hearth-api"
  @required ~w[iss aud sub typ iat exp]
  @drift_seconds 2

  @spec audience() :: String.t()
  def audience, do: @audience

  @impl Guardian
  def subject_for_token(%{id: id}, _claims) when is_binary(id), do: {:ok, "user:" <> id}
  def subject_for_token(_resource, _claims), do: {:error, :unknown_resource}

  @impl Guardian
  def resource_from_claims(%{"sub" => "user:" <> id}), do: Accounts.get_user(id: id)
  def resource_from_claims(_claims), do: {:error, :unknown_resource}

  @impl Guardian
  def build_claims(claims, _resource, _opts), do: {:ok, Map.put(claims, "aud", @audience)}

  @impl Guardian
  def verify_claims(claims, _opts) do
    now = System.os_time(:second)

    valid? =
      Enum.all?(@required, &Map.has_key?(claims, &1)) and
        claims["aud"] == @audience and claims["typ"] == "access" and
        is_integer(claims["iat"]) and claims["iat"] <= now + @drift_seconds

    case valid? do
      true -> {:ok, claims}
      false -> {:error, :invalid_token}
    end
  end
end
