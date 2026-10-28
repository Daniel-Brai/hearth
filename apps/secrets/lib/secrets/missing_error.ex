defmodule Secrets.MissingError do
  defexception [:names]

  @type t :: %__MODULE__{names: [String.t()]}

  @impl Exception
  def message(%__MODULE__{names: names}) do
    "Vault has no value for #{Enum.join(names, ", ")}"
  end
end
