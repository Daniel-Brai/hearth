defmodule Hearth.Chat.PollOption do
  use Hearth.Repo.Schema, prefix: "chat"

  alias Hearth.Common.T
  alias Hearth.Vault

  schema "poll_options" do
    field :poll_id, Ecto.UUID
    field :label, Vault.Binary
    field :position, :integer

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          poll_id: T.id(),
          label: String.t(),
          position: non_neg_integer()
        }
end
