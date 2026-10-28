defmodule Hearth.Vault.Binary do
  use Ecto.Type

  alias Hearth.Vault

  @impl Ecto.Type
  def type, do: :binary

  @impl Ecto.Type
  def cast(value) when is_binary(value), do: {:ok, value}
  def cast(_value), do: :error

  @impl Ecto.Type
  def dump(value) when is_binary(value), do: {:ok, Vault.encrypt(value)}
  def dump(_value), do: :error

  @impl Ecto.Type
  def load(value) when is_binary(value), do: Vault.decrypt(value)
  def load(_value), do: :error
end
