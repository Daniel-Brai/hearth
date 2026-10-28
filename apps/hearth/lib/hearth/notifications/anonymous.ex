defmodule Hearth.Notifications.Anonymous do
  alias Hearth.Notifications.Notifiable

  @enforce_keys [:email]
  defstruct [:email, :name]

  @type t :: %__MODULE__{email: String.t(), name: nil | String.t()}

  defimpl Notifiable do
    def recipients(anonymous, :mail), do: {anonymous.name, anonymous.email}
    def recipients(_anonymous, :web_push), do: []
  end
end
