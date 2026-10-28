defmodule Hearth.IAM.Object do
  alias Hearth.Common.T

  @enforce_keys [:type]
  defstruct ~w[type community_id author_id]a

  @type t :: %__MODULE__{
          type: atom(),
          community_id: nil | T.id(),
          author_id: nil | T.id()
        }

  @spec from(map()) :: t()
  def from(%{type: type} = attrs) when is_atom(type) do
    %__MODULE__{
      type: type,
      community_id: attrs[:community_id],
      author_id: attrs[:author_id]
    }
  end
end
