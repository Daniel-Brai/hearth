defmodule Hearth.Instance.GitHubError do
  @fields [:status, :message]

  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{status: pos_integer(), message: nil | String.t()}

  @spec from!(map()) :: no_return() | t()
  def from!(%{} = data) do
    %{"status" => status} = data

    %__MODULE__{status: status, message: data["message"]}
  end
end
