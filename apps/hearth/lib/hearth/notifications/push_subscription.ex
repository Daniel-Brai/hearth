defmodule Hearth.Notifications.PushSubscription do
  use Hearth.Repo.Schema, prefix: "notifications"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @fields ~w[user_id endpoint p256dh auth user_agent last_used_at]a

  # Browsers only hand out endpoints on these push services
  @push_hosts ~w[fcm.googleapis.com updates.push.services.mozilla.com web.push.apple.com]
  @push_suffix ".notify.windows.com"
  @changeable [:last_used_at]

  schema "push_subscriptions" do
    field :user_id, Ecto.UUID
    field :endpoint, :string
    field :p256dh, :string
    field :auth, :string
    field :user_agent, :string
    field :last_used_at, :utc_datetime_usec

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          user_id: T.id(),
          endpoint: String.t(),
          p256dh: String.t(),
          auth: String.t(),
          user_agent: nil | String.t(),
          last_used_at: nil | DateTime.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = subscription, %{} = params) do
    subscription
    |> cast(params, @fields)
    |> validate_required(@fields -- [:user_agent, :last_used_at])
    |> validate_length(:endpoint, max: 2_000)
    |> validate_length(:p256dh, max: 100)
    |> validate_length(:auth, max: 100)
    |> validate_change(:endpoint, &secure_url/2)
    |> unique_constraint(:endpoint)
    |> foreign_key_constraint(:user_id)
  end

  @spec link(map()) :: {:ok, t()} | {:error, Changeset.t()}
  def link(%{} = params) do
    %__MODULE__{}
    |> changeset(params)
    |> Repo.insert(
      on_conflict: {:replace, [:user_id, :p256dh, :auth, :user_agent, :updated_at]},
      conflict_target: :endpoint,
      returning: true
    )
  end

  defp secure_url(:endpoint, endpoint) do
    with {:ok, %URI{scheme: "https", host: host}} when is_binary(host) <- URI.new(endpoint),
         true <- host in @push_hosts or String.ends_with?(host, @push_suffix) do
      []
    else
      false -> [endpoint: "must be a browser push service"]
      _other -> [endpoint: "must be an https address"]
    end
  end
end
