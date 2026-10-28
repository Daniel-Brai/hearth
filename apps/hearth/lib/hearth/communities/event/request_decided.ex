defmodule Hearth.Communities.RequestDecided do
  alias Hearth.Common.T

  @fields ~w[request_id requester_id status community_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          request_id: T.id(),
          requester_id: T.id(),
          status: :approved | :declined,
          community_id: nil | T.id()
        }
end
