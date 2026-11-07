defmodule Hearth.Forum.SearchHit do
  alias Hearth.Common.T
  alias Hearth.Forum.Post

  @fields ~w[post reply_id excerpt]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          post: Post.t(),
          reply_id: nil | T.id(),
          excerpt: String.t()
        }
end
