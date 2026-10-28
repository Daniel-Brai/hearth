defmodule Hearth.Auth.Token do
  use Hearth.Repo.Schema, prefix: "auth"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Repo

  @contexts ~w[session sign_in_code sign_up change_email undo_email_change transfer_ownership]a
  @fields ~w[user_id context token_hash sent_to data user_agent ip expires_at]a
  @max_attempts 5

  @ttl %{
    session: 60 * 24 * 60,
    sign_in_code: 15,
    sign_up: 60,
    change_email: 15,
    undo_email_change: 7 * 24 * 60,
    transfer_ownership: 15
  }

  schema "user_tokens" do
    field :user_id, Ecto.UUID
    field :context, Ecto.Enum, values: @contexts
    field :token_hash, :binary, redact: true
    field :sent_to, :string
    field :data, :map, default: %{}
    field :attempts, :integer, default: 0
    field :user_agent, :string
    # Sealed at rest since it says roughly where someone signs in from
    field :ip, Hearth.Vault.Binary
    field :expires_at, :utc_datetime_usec

    timestamps(updated_at: false)
  end

  @type context ::
          :session
          | :sign_in_code
          | :sign_up
          | :change_email
          | :undo_email_change
          | :transfer_ownership

  @type t :: %__MODULE__{
          id: T.id(),
          user_id: nil | T.id(),
          context: context(),
          token_hash: binary(),
          sent_to: nil | String.t(),
          data: map(),
          attempts: integer(),
          user_agent: nil | String.t(),
          ip: nil | String.t(),
          expires_at: DateTime.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = token, %{} = params) do
    token
    |> cast(params, @fields)
    |> validate_required(@fields -- ~w[user_id sent_to data user_agent ip]a)
    |> unique_constraint(:token_hash)
  end

  @spec ttl(context()) :: pos_integer()
  def ttl(context), do: Map.fetch!(@ttl, context)

  @spec create_code(context(), String.t(), map()) :: {:ok, String.t()} | {:error, Changeset.t()}
  def create_code(context, sent_to, %{} = params \\ %{}) do
    code = random_code()

    params =
      Map.merge(params, %{
        context: context,
        sent_to: sent_to,
        token_hash: hash_code(context, sent_to, code),
        expires_at: expires_at(context)
      })

    existing = where(__MODULE__, context: ^context, sent_to: ^sent_to)

    Repo.transact(fn ->
      Repo.delete_all(existing)

      with {:ok, _token} <- insert(%__MODULE__{}, params), do: {:ok, code}
    end)
  end

  # The fifth wrong attempt deletes the token
  @spec use_code(context(), keyword(), String.t()) :: {:ok, t()} | {:error, :invalid | :expired}
  def use_code(context, by, code) when is_binary(code) do
    case latest(context, by) do
      nil -> {:error, :invalid}
      %__MODULE__{} = token -> check_code(token, code)
    end
  end

  @spec create_random(context(), map()) :: {:ok, String.t()} | {:error, Changeset.t()}
  def create_random(context, %{} = params) do
    raw = :crypto.strong_rand_bytes(32)

    params =
      Map.merge(params, %{
        context: context,
        token_hash: :crypto.hash(:sha256, raw),
        expires_at: expires_at(context)
      })

    with {:ok, _token} <- insert(%__MODULE__{}, params) do
      {:ok, Base.url_encode64(raw, padding: false)}
    end
  end

  @spec find_random(context(), String.t()) :: {:ok, t()} | {:error, :invalid | :expired}
  def find_random(context, value) when is_binary(value) do
    with {:ok, hash} <- hash_random(value),
         %__MODULE__{} = token <- Repo.get_by(__MODULE__, context: context, token_hash: hash),
         false <- expired?(token) do
      {:ok, token}
    else
      true -> {:error, :expired}
      _other -> {:error, :invalid}
    end
  end

  # Deleted and fetched in one statement so only one of two concurrent requests gets it
  @spec take_random(context(), String.t()) :: {:ok, t()} | {:error, :invalid | :expired}
  def take_random(context, value) when is_binary(value) do
    with {:ok, hash} <- hash_random(value),
         %__MODULE__{} = token <- take(context, hash),
         false <- expired?(token) do
      {:ok, token}
    else
      true -> {:error, :expired}
      _other -> {:error, :invalid}
    end
  end

  @spec delete_all(keyword()) :: :ok
  def delete_all(by) when is_list(by) do
    __MODULE__
    |> where(^by)
    |> Repo.delete_all()

    :ok
  end

  @spec delete_expired_tokens() :: :ok
  def delete_expired_tokens do
    now = DateTime.utc_now()

    __MODULE__
    |> where([t], t.expires_at < ^now)
    |> Repo.delete_all()

    :ok
  end

  @spec expired?(t()) :: boolean()
  def expired?(%__MODULE__{expires_at: expires_at}) do
    DateTime.before?(expires_at, DateTime.utc_now())
  end

  defp hash_random(value) do
    with {:ok, raw} <- Base.url_decode64(value, padding: false) do
      {:ok, :crypto.hash(:sha256, raw)}
    end
  end

  defp take(context, hash) do
    query = from t in __MODULE__, where: [context: ^context, token_hash: ^hash], select: t

    {_count, tokens} = Repo.delete_all(query)

    List.first(tokens)
  end

  defp latest(context, by) do
    __MODULE__
    |> where(^by)
    |> where(context: ^context)
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  defp check_code(token, code) do
    expected = hash_code(token.context, token.sent_to, code)

    cond do
      expired?(token) ->
        Repo.delete(token)
        {:error, :expired}

      :crypto.hash_equals(token.token_hash, expected) ->
        Repo.delete(token)
        {:ok, token}

      true ->
        count_attempt(token)
    end
  end

  defp count_attempt(%__MODULE__{attempts: attempts} = token)
       when attempts + 1 >= @max_attempts do
    Repo.delete(token)
    {:error, :invalid}
  end

  defp count_attempt(%__MODULE__{id: id}) do
    __MODULE__
    |> where(id: ^id)
    |> Repo.update_all(inc: [attempts: 1])

    {:error, :invalid}
  end

  defp expires_at(context) do
    DateTime.add(DateTime.utc_now(), ttl(context), :minute)
  end

  defp random_code do
    <<value::unsigned-32>> = :crypto.strong_rand_bytes(4)

    value
    |> rem(1_000_000)
    |> Integer.to_string()
    |> String.pad_leading(6, "0")
  end

  # Keyed with the server secret so a leaked table cannot be searched for
  # the million possible codes
  defp hash_code(context, sent_to, code) do
    key = Application.fetch_env!(:hearth, :secret_key_base)

    :crypto.mac(:hmac, :sha256, key, [Atom.to_string(context), 0, sent_to, 0, code])
  end
end
