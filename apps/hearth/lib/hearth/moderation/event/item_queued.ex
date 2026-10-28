defmodule Hearth.Moderation.ItemQueued do
  # Not sent to sockets so nobody but moderators learns what was reported

  alias Hearth.Common.T

  @fields ~w[item_id community_id source subject_type subject_id author_id reporter_id]a
  @enforce_keys @fields
  defstruct @fields

  @type t :: %__MODULE__{
          item_id: T.id(),
          community_id: nil | T.id(),
          source: :automatic | :report | :instance,
          subject_type: :post | :reply | :message,
          subject_id: T.id(),
          author_id: T.id(),
          reporter_id: nil | T.id()
        }
end
