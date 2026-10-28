defmodule Hearth.Storage.Object do
  @enforce_keys [:key, :size]
  defstruct ~w[key size content_type etag]a

  @type t :: %__MODULE__{
          key: String.t(),
          size: non_neg_integer(),
          content_type: nil | String.t(),
          etag: nil | String.t()
        }
end
