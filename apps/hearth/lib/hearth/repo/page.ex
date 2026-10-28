defmodule Hearth.Repo.Page do
  alias Flop.Meta

  @enforce_keys [:data]
  defstruct [:data, meta: %Meta{}]

  @type t :: %__MODULE__{
          data: [struct()],
          meta: Meta.t()
        }
end
