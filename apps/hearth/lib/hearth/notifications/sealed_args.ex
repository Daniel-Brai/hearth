defmodule Hearth.Notifications.SealedArgs do
  # Oban stores and logs job arguments in plain text so sensitive parts are sealed

  alias Hearth.Vault

  @spec seal(term()) :: String.t()
  def seal(value) do
    value
    |> Jason.encode!()
    |> Vault.encrypt()
    |> Base.encode64()
  end

  # Raises when the value was changed so the job fails instead of sending something empty
  @spec open!(String.t()) :: term()
  def open!(sealed) when is_binary(sealed) do
    {:ok, json} = sealed |> Base.decode64!() |> Vault.decrypt()

    Jason.decode!(json)
  end
end
