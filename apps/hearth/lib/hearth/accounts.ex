defmodule Hearth.Accounts do
  exports = [AvatarChanged, EmailChanged, Privacy, Settings, User, UserCreated]

  use Boundary,
    deps: [Hearth.Buffer, Hearth.Common, Hearth.PubSub, Hearth.Repo, Hearth.TranscriptionPolicy],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts.AvatarChanged
  alias Hearth.Accounts.EmailChanged
  alias Hearth.Accounts.LastSeen
  alias Hearth.Accounts.Privacy
  alias Hearth.Accounts.Settings
  alias Hearth.Accounts.Taken
  alias Hearth.Accounts.User
  alias Hearth.Accounts.UserCreated
  alias Hearth.Buffer
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.PubSub

  @topic "accounts"

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec register_user(map()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def register_user(%{} = params) do
    with {:ok, user} <- User.register(params) do
      broadcast(%UserCreated{user_id: user.id, username: user.username, email: user.email})

      {:ok, user}
    end
  end

  @spec get_user(keyword()) :: {:ok, User.t()} | {:error, :not_found}
  def get_user(opts) when is_list(opts) do
    case User.get(opts) do
      nil -> {:error, :not_found}
      %User{} = user -> {:ok, user}
    end
  end

  @spec list_users([T.id()]) :: [User.t()]
  def list_users(ids) when is_list(ids) do
    User.all(id: Enum.uniq(ids), deleted_at: nil)
  end

  @spec digest_due_ids(DateTime.t(), 0..23) :: [T.id()]
  def digest_due_ids(%DateTime{} = at, hour), do: User.digest_due_ids(at, hour)

  @spec list_instance_admins() :: [User.t()]
  def list_instance_admins, do: User.all(is_instance_admin: true, deleted_at: nil)

  @spec list_users_by_username([String.t()]) :: [User.t()]
  def list_users_by_username(usernames) when is_list(usernames) do
    User.all(username: Enum.uniq(usernames), deleted_at: nil)
  end

  @spec search_users(String.t(), [T.id()], pos_integer()) :: [User.t()]
  def search_users(query, ids, limit) when is_binary(query) and is_list(ids) do
    query
    |> String.trim()
    |> User.search(ids, limit)
  end

  @spec list_people(String.t(), [T.id()], [T.id()], pos_integer()) :: [User.t()]
  def list_people(query, ids, online_ids, limit) when is_binary(query) and is_list(ids),
    do: query |> String.trim() |> User.directory(ids, online_ids, limit)

  # People who hide their presence are left out, as in the people directory
  @spec presence_shown([T.id()]) :: [T.id()]
  def presence_shown(user_ids) when is_list(user_ids), do: User.presence_shown(user_ids)

  # Buffered so it is cheap to call on every request
  @spec touch_last_seen(User.t()) :: :ok
  def touch_last_seen(%User{id: id}) do
    now = System.os_time(:microsecond)

    Buffer.put_newer(LastSeen, id, now, now)
  end

  # Broadcasts AvatarChanged when the avatar changes so the old file gets deleted
  @spec update_profile(User.t(), map()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def update_profile(%User{} = user, %{} = params) do
    with {:ok, updated} <- User.update_profile(user, params) do
      if updated.avatar_id != user.avatar_id do
        broadcast(%AvatarChanged{
          user_id: user.id,
          previous_avatar_id: user.avatar_id,
          avatar_id: updated.avatar_id
        })
      end

      {:ok, updated}
    end
  end

  @spec change_email(User.t(), String.t()) :: {:ok, User.t()} | {:error, Changeset.t()}
  def change_email(%User{} = user, email) when is_binary(email) do
    with {:ok, user} <- User.change_email(user, email) do
      broadcast(%EmailChanged{user_id: user.id, email: user.email})

      {:ok, user}
    end
  end

  @spec update_settings(User.t(), map()) :: {:ok, Settings.t()} | {:error, Changeset.t()}
  def update_settings(%User{} = user, %{} = params) do
    with {:ok, user} <- User.update_settings(user, params), do: {:ok, user.settings}
  end

  @spec update_privacy(User.t(), map()) :: {:ok, Privacy.t()} | {:error, Changeset.t()}
  def update_privacy(%User{} = user, %{} = params) do
    with {:ok, user} <- User.update_privacy(user, params), do: {:ok, user.privacy}
  end

  @spec replace_links(User.t(), [map()]) :: {:ok, User.t()} | {:error, Changeset.t()}
  def replace_links(%User{} = user, links) when is_list(links) do
    User.replace_links(user, links)
  end

  @spec username_available?(String.t()) :: boolean()
  def username_available?(username) when is_binary(username) do
    key = Common.normalize(username)

    Common.valid_username?(key) and
      (not Taken.member?(:username, key) or not User.exists?(username: key))
  end

  # Never expose this in a response, it would reveal who has signed up
  @spec email_registered?(String.t()) :: boolean()
  def email_registered?(email) when is_binary(email) do
    key = Common.normalize(email)

    Taken.member?(:email, key) and User.exists?(email: key)
  end

  defp broadcast(event), do: PubSub.broadcast(@topic, event)
end
