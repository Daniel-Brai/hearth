defmodule Hearth.Common.Id do
  alias Ecto.UUID
  alias Hearth.Common.T

  @generate [version: 7, precision: :monotonic]

  @spec options() :: keyword()
  def options, do: @generate

  @spec new() :: T.id()
  def new, do: UUID.generate(@generate)

  @spec valid?(term()) :: boolean()
  def valid?(value) when is_binary(value), do: match?({:ok, _uuid}, UUID.cast(value))
  def valid?(_value), do: false
end
