defmodule Hearth.Notifications.Delivery do
  use Hearth.Repo.Schema, prefix: "notifications"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @fields ~w[user_id template to provider_message_id status error]a

  schema "email_deliveries" do
    field :user_id, Ecto.UUID
    field :template, :string
    field :to, :string
    field :provider_message_id, :string
    field :status, Ecto.Enum, values: ~w[sent failed bounced]a
    field :error, :string

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          user_id: nil | T.id(),
          template: String.t(),
          to: String.t(),
          provider_message_id: nil | String.t(),
          status: :sent | :failed | :bounced,
          error: nil | String.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = delivery, %{} = params) do
    delivery
    |> cast(params, @fields)
    |> validate_required(~w[template to status]a)
  end
end
