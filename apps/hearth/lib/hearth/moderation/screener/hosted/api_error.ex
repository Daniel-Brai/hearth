defmodule Hearth.Moderation.Screener.Hosted.ApiError do
  @fields [:status, :message]

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{status: pos_integer(), message: nil | String.t()}

  @spec from!(map()) :: no_return() | t()
  def from!(%{} = data) do
    %{"status" => status} = data

    message =
      case data do
        %{"error" => %{"message" => message}} -> message
        _other -> nil
      end

    %__MODULE__{status: status, message: message}
  end
end
