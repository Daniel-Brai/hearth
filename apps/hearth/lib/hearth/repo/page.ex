defmodule Hearth.Repo.Page do
  alias Flop.Meta

  @enforce_keys [:data]
  defstruct [:data, meta: %Meta{}]

  @type t :: %__MODULE__{
          data: [struct()],
          meta: Meta.t()
        }

  # For lists paged by hand with a cursor from the last row's place in their own order
  @spec new([struct()], nil | String.t()) :: t()
  def new(data, next_cursor) when is_list(data) do
    %__MODULE__{
      data: data,
      meta: %Meta{end_cursor: next_cursor, has_next_page?: next_cursor != nil}
    }
  end
end
