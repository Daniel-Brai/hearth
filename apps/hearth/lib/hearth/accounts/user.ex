defmodule Hearth.Accounts.User do
  use Hearth.Repo.Schema, prefix: "accounts"

  import Ecto.Changeset
  import Hearth.Repo.Changeset

  alias Ecto.Changeset
  alias Hearth.Accounts.Privacy
  alias Hearth.Accounts.Settings
  alias Hearth.Common
  alias Hearth.Common.Link
  alias Hearth.Common.T

  @profile ~w[display_name bio pronouns location timezone locale avatar_id]a
  @changeable @profile
  @profile_keys @profile ++ Enum.map(@profile, &Atom.to_string/1)

  schema "users" do
    field :username, :string
    field :display_name, :string
    field :email, :string
    field :email_confirmed_at, :utc_datetime_usec
    field :password_hash, :string, redact: true
    field :avatar_id, Ecto.UUID
    field :bio, :string
    field :pronouns, :string
    field :location, :string
    field :timezone, :string
    field :locale, :string
    field :last_seen_at, :utc_datetime_usec
    field :is_instance_admin, :boolean, default: false
    field :deleted_at, :utc_datetime_usec

    embeds_one :settings, Settings, on_replace: :update
    embeds_one :privacy, Privacy, on_replace: :update
    embeds_many :links, Link, on_replace: :delete

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          username: String.t(),
          display_name: nil | String.t(),
          email: String.t(),
          email_confirmed_at: nil | DateTime.t(),
          password_hash: nil | String.t(),
          avatar_id: nil | T.id(),
          bio: nil | String.t(),
          pronouns: nil | String.t(),
          location: nil | String.t(),
          timezone: nil | String.t(),
          locale: nil | String.t(),
          last_seen_at: nil | DateTime.t(),
          is_instance_admin: boolean(),
          deleted_at: nil | DateTime.t(),
          settings: Settings.t(),
          privacy: Privacy.t(),
          links: [Link.t()]
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = user, %{} = params) do
    user
    |> cast(params, [:username, :email | @profile])
    |> update_change(:username, &Common.normalize/1)
    |> update_change(:email, &Common.normalize/1)
    |> validate_required([:username, :email])
    |> validate_username()
    |> validate_email(:email)
    |> validate_profile()
    |> unique_constraint(:username)
    |> unique_constraint(:email)
    |> check_constraint(:username, name: :username_unchanged, message: "cannot be changed")
  end

  @spec links_changeset(struct(), [map()]) :: Changeset.t()
  def links_changeset(%__MODULE__{} = user, links) when is_list(links) do
    user
    |> cast(Link.unique(%{links: links}), [])
    |> cast_embed(:links, with: &Link.changeset/2)
  end

  @first_account_lock 7_337_001

  @spec register(map()) :: {:ok, t()} | {:error, Changeset.t()}
  def register(%{} = params) do
    case Repo.exists?(__MODULE__) do
      true -> insert(new(false), params)
      false -> register_first(params)
    end
  end

  # Only a sign up that finds no account takes the lock, so two on a fresh install
  # take turns and the second sees the first. It is a session lock released after
  # the commit, since a transaction lock would last until a test's sandbox ends
  defp register_first(params) do
    Repo.checkout(fn ->
      Repo.query!("SELECT pg_advisory_lock($1)", [@first_account_lock])

      try do
        Repo.transact(fn -> insert(new(not Repo.exists?(__MODULE__)), params) end)
      after
        Repo.query!("SELECT pg_advisory_unlock($1)", [@first_account_lock])
      end
    end)
  end

  defp new(admin?) do
    %__MODULE__{
      email_confirmed_at: DateTime.utc_now(),
      is_instance_admin: admin?,
      settings: %Settings{},
      privacy: %Privacy{}
    }
  end

  @spec update_profile(t(), map()) :: {:ok, t()} | {:error, Changeset.t()}
  def update_profile(%__MODULE__{} = user, %{} = params) do
    embeds =
      for key <- [:links, :privacy],
          value = params[key] || params[Atom.to_string(key)],
          value != nil,
          into: %{},
          do: {key, value}

    user
    |> changeset(Map.take(params, @profile_keys))
    |> cast(Link.unique(embeds), [])
    |> cast_embed(:links, with: &Link.changeset/2)
    |> cast_embed(:privacy)
    |> Repo.update()
  end

  # How alike a typed word and a name must be to count from 0 to 1
  @fuzzy 0.3

  @spec search(String.t(), [T.id()], pos_integer()) :: [t()]
  def search(query, ids, limit) do
    base =
      from(u in __MODULE__,
        where: u.id in ^ids and is_nil(u.deleted_at),
        limit: ^limit
      )

    query
    |> String.downcase()
    |> matching(base)
    |> Repo.all()
  end

  # Online people come first unless they hide it then the usual order of the search
  @spec directory(String.t(), [T.id()], [T.id()], pos_integer()) :: [t()]
  def directory(query, ids, online_ids, limit) do
    base =
      from(u in __MODULE__,
        where: u.id in ^ids and is_nil(u.deleted_at),
        order_by: [
          desc:
            u.id in ^online_ids and
              fragment("coalesce(?->>'presence', 'everyone') <> 'nobody'", u.privacy)
        ],
        limit: ^limit
      )

    query
    |> String.downcase()
    |> matching(base)
    |> Repo.all()
  end

  defp matching("", base), do: order_by(base, [u], asc: u.username)

  defp matching(typed, base) do
    pattern = String.replace(typed, ~w[\\ % _], &("\\" <> &1))
    prefix = pattern <> "%"
    anywhere = "%" <> pattern <> "%"

    from(u in base,
      where:
        fragment("lower(?::text) LIKE ?", u.username, ^prefix) or
          fragment("lower(?) LIKE ?", u.display_name, ^anywhere) or
          fragment("word_similarity(?, lower(?::text)) > ?", ^typed, u.username, ^@fuzzy) or
          fragment(
            "word_similarity(?, lower(coalesce(?, ''))) > ?",
            ^typed,
            u.display_name,
            ^@fuzzy
          ),
      order_by: [
        desc: fragment("lower(?::text) LIKE ?", u.username, ^prefix),
        desc:
          fragment(
            "greatest(word_similarity(?, lower(?::text)), word_similarity(?, lower(coalesce(?, ''))))",
            ^typed,
            u.username,
            ^typed,
            u.display_name
          ),
        asc: u.username
      ]
    )
  end

  # A time zone Postgres doesn't know counts as UTC
  @spec digest_due_ids(DateTime.t(), 0..23) :: [T.id()]
  def digest_due_ids(%DateTime{} = at, hour) do
    query =
      from(u in __MODULE__,
        left_join: tz in fragment("SELECT name FROM pg_timezone_names"),
        on: tz.name == u.timezone,
        where: is_nil(u.deleted_at),
        where:
          fragment(
            "extract(hour FROM ?::timestamptz AT TIME ZONE coalesce(?, 'Etc/UTC')) = ?",
            ^at,
            tz.name,
            ^hour
          ),
        where:
          fragment("coalesce(?->>'digest', 'weekly') = 'daily'", u.settings) or
            (fragment("coalesce(?->>'digest', 'weekly') = 'weekly'", u.settings) and
               fragment(
                 "extract(isodow FROM ?::timestamptz AT TIME ZONE coalesce(?, 'Etc/UTC')) = 1",
                 ^at,
                 tz.name
               )),
        select: u.id
      )

    Repo.all(query)
  end

  @spec update_settings(t(), map()) :: {:ok, t()} | {:error, Changeset.t()}
  def update_settings(%__MODULE__{} = user, %{} = params) do
    user
    |> cast(%{settings: params}, [])
    |> cast_embed(:settings)
    |> Repo.update()
  end

  @spec update_privacy(t(), map()) :: {:ok, t()} | {:error, Changeset.t()}
  def update_privacy(%__MODULE__{} = user, %{} = params) do
    user
    |> cast(%{privacy: params}, [])
    |> cast_embed(:privacy)
    |> Repo.update()
  end

  @spec change_email(t(), String.t()) :: {:ok, t()} | {:error, Changeset.t()}
  def change_email(%__MODULE__{} = user, email) do
    user
    |> email_changeset(email)
    |> Repo.update()
  end

  @spec replace_links(t(), [map()]) :: {:ok, t()} | {:error, Changeset.t()}
  def replace_links(%__MODULE__{} = user, links) do
    user
    |> links_changeset(links)
    |> Repo.update()
  end

  @spec email_changeset(struct(), String.t()) :: Changeset.t()
  def email_changeset(%__MODULE__{} = user, email) do
    user
    |> cast(%{email: email}, [:email])
    |> update_change(:email, &Common.normalize/1)
    |> validate_required([:email])
    |> validate_email(:email)
    |> unique_constraint(:email)
    |> put_change(:email_confirmed_at, DateTime.utc_now())
  end

  defp validate_username(changeset) do
    validate_change(changeset, :username, fn :username, username ->
      case Common.valid_username?(username) do
        true -> []
        false -> [username: "must be 3 to 20 lowercase letters, digits or underscores"]
      end
    end)
  end

  defp validate_profile(changeset) do
    changeset
    |> validate_length(:display_name, max: 50)
    |> validate_length(:bio, max: 300)
    |> validate_length(:pronouns, max: 40)
    |> validate_length(:location, max: 80)
    |> validate_length(:timezone, max: 64)
    |> validate_length(:locale, max: 16)
  end
end
