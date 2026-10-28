defmodule Hearth.Auth do
  events = [
    EmailChangeBlocked,
    EmailChangeCodeRequested,
    EmailChangeConfirmed,
    EmailChangeUndone,
    SignedIn,
    SignInCodeRequested,
    TransferCodeRequested
  ]

  exports =
    case Mix.env() do
      :test -> events ++ [Identity, Token]
      _env -> events
    end

  use Boundary,
    deps: [Hearth.Accounts, Hearth.Common, Hearth.PubSub, Hearth.Repo, Hearth.Vault],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Auth.Command.RotateSession
  alias Hearth.Auth.EmailChangeBlocked
  alias Hearth.Auth.EmailChangeCodeRequested
  alias Hearth.Auth.EmailChangeConfirmed
  alias Hearth.Auth.EmailChangeUndone
  alias Hearth.Auth.EmailInput
  alias Hearth.Auth.Identity
  alias Hearth.Auth.Provider
  alias Hearth.Auth.SignedIn
  alias Hearth.Auth.SignInCodeRequested
  alias Hearth.Auth.Token
  alias Hearth.Auth.TransferCodeRequested
  alias Hearth.Common
  alias Hearth.PubSub

  @topic "auth"
  @recent_minutes 10

  @type sign_in :: {:ok, User.t()} | {:sign_up, String.t()}

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec providers() :: [Provider.t()]
  def providers, do: Provider.enabled()

  # Sent even when the email has no account so the answer never says who signed up
  @spec request_sign_in_code(String.t()) :: :ok | {:error, Changeset.t()}
  def request_sign_in_code(email) when is_binary(email) do
    with {:ok, email} <- EmailInput.cast(email),
         {:ok, code} <- Token.create_code(:sign_in_code, email) do
      ttl = Token.ttl(:sign_in_code)

      broadcast(%SignInCodeRequested{email: email, code: code, ttl: ttl})
    end
  end

  # {:sign_up, token} means the email has no account yet
  @spec verify_sign_in_code(String.t(), String.t()) :: sign_in() | {:error, :invalid | :expired}
  def verify_sign_in_code(email, code) when is_binary(email) and is_binary(code) do
    email = Common.normalize(email)

    with {:ok, _token} <- Token.use_code(:sign_in_code, [sent_to: email], code) do
      case Accounts.get_user(email: email) do
        {:ok, user} -> signed_in(user, :code)
        {:error, :not_found} -> sign_up(email, %{})
      end
    end
  end

  # A verified email with no account gets a sign up token, an unverified one is refused
  @spec sign_in_with_identity(Provider.t(), map()) :: sign_in() | {:error, :email_not_verified}
  def sign_in_with_identity(provider, %{"sub" => uid} = claims) do
    uid = to_string(uid)

    case Identity.get(provider: provider, provider_uid: uid) do
      %Identity{user_id: id} ->
        with {:ok, user} <- Accounts.get_user(id: id), do: signed_in(user, provider)

      nil ->
        sign_in_with_email(provider, uid, claims)
    end
  end

  @spec oauth_url(String.t(), String.t()) ::
          {:ok, %{url: String.t(), session_params: map()}} | {:error, :not_found}
  def oauth_url(provider, redirect_uri) do
    with {:ok, provider} <- Provider.cast(provider) do
      Provider.authorize_url(provider, redirect_uri)
    end
  end

  @spec oauth_callback(String.t(), String.t(), map(), map()) ::
          sign_in() | {:error, :not_found | :email_not_verified | term()}
  def oauth_callback(provider, redirect_uri, %{} = params, %{} = session_params) do
    with {:ok, provider} <- Provider.cast(provider),
         {:ok, claims} <- Provider.callback(provider, redirect_uri, params, session_params) do
      sign_in_with_identity(provider, claims)
    end
  end

  @spec sign_up_details(String.t()) ::
          {:ok, %{name: nil | String.t(), username: nil | String.t()}}
          | {:error, :invalid | :expired}
  def sign_up_details(sign_up_token) when is_binary(sign_up_token) do
    with {:ok, token} <- Token.find_random(:sign_up, sign_up_token) do
      {:ok, %{name: token.data["name"], username: token.data["username"]}}
    end
  end

  @spec register_user(String.t(), String.t(), nil | String.t()) ::
          {:ok, User.t()} | {:error, :invalid | :expired | Changeset.t()}
  def register_user(sign_up_token, username, display_name \\ nil)
      when is_binary(sign_up_token) and is_binary(username) do
    with {:ok, token} <- Token.find_random(:sign_up, sign_up_token) do
      params = %{
        email: token.sent_to,
        username: username,
        display_name: display_name || token.data["name"]
      }

      with {:ok, user} <- Accounts.register_user(params),
           {:ok, _identity} <- link_identity(user, token.data) do
        Token.delete(token)

        signed_in(user, method(token.data))
      end
    end
  end

  @spec create_session(User.t(), map()) :: {:ok, String.t()} | {:error, Changeset.t()}
  def create_session(%User{id: id}, %{} = meta \\ %{}) do
    params =
      meta
      |> Map.take([:user_agent, :ip])
      |> Map.put(:user_id, id)

    Token.create_random(:session, params)
  end

  @spec rotate_session(String.t(), map()) ::
          {:ok, User.t(), String.t()} | {:error, :invalid | :expired | :not_found}
  def rotate_session(session, %{} = meta \\ %{}) when is_binary(session) do
    RotateSession.execute(session, meta)
  end

  # Changing email asks for a fresh sign in code first when the session is older
  @spec recent_session?(String.t()) :: boolean()
  def recent_session?(session) when is_binary(session) do
    since = DateTime.add(DateTime.utc_now(), -@recent_minutes, :minute)

    case Token.find_random(:session, session) do
      {:ok, token} -> DateTime.after?(token.inserted_at, since)
      {:error, _reason} -> false
    end
  end

  @spec delete_session(String.t()) :: :ok
  def delete_session(session) when is_binary(session) do
    with {:ok, token} <- Token.find_random(:session, session) do
      Token.delete(token)
    end

    :ok
  end

  @spec delete_all_sessions(User.t()) :: :ok
  def delete_all_sessions(%User{id: id}), do: Token.delete_all(user_id: id, context: :session)

  # An address already in use gets a note instead so the answer never reveals it
  @spec request_email_change(User.t(), String.t()) :: :ok | {:error, Changeset.t()}
  def request_email_change(%User{} = user, email) when is_binary(email) do
    with {:ok, email} <- EmailInput.cast_new(email, user.email) do
      case Accounts.email_registered?(email) do
        true -> broadcast(%EmailChangeBlocked{user_id: user.id, email: email})
        false -> send_email_change_code(user, email)
      end
    end
  end

  @spec confirm_email_change(User.t(), String.t()) ::
          {:ok, User.t()} | {:error, :invalid | :expired | Changeset.t()}
  def confirm_email_change(%User{id: id} = user, code) when is_binary(code) do
    params = %{user_id: id, sent_to: user.email}

    with {:ok, token} <- Token.use_code(:change_email, [user_id: id], code),
         {:ok, changed} <- Accounts.change_email(user, token.sent_to),
         {:ok, undo} <- Token.create_random(:undo_email_change, params) do
      broadcast(%EmailChangeConfirmed{
        user_id: id,
        old_email: user.email,
        new_email: changed.email,
        undo_token: undo,
        ttl: Token.ttl(:undo_email_change)
      })

      {:ok, changed}
    end
  end

  @spec undo_email_change(String.t()) ::
          {:ok, User.t()} | {:error, :invalid | :expired | :not_found | Changeset.t()}
  def undo_email_change(undo_token) when is_binary(undo_token) do
    with {:ok, token} <- Token.find_random(:undo_email_change, undo_token),
         {:ok, user} <- Accounts.get_user(id: token.user_id),
         {:ok, user} <- Accounts.change_email(user, token.sent_to) do
      Token.delete_all(user_id: user.id, context: :undo_email_change)
      delete_all_sessions(user)

      broadcast(%EmailChangeUndone{user_id: user.id, email: user.email})

      {:ok, user}
    end
  end

  @spec request_transfer_code(User.t(), %{
          :id => Common.T.id(),
          :name => String.t(),
          optional(atom()) => any()
        }) ::
          :ok | {:error, Changeset.t()}
  def request_transfer_code(%User{} = owner, %{id: id, name: name}) do
    params = %{user_id: owner.id, data: %{"community_id" => id}}

    with {:ok, code} <- Token.create_code(:transfer_ownership, owner.email, params) do
      ttl = Token.ttl(:transfer_ownership)

      broadcast(%TransferCodeRequested{
        user_id: owner.id,
        email: owner.email,
        community_name: name,
        code: code,
        ttl: ttl
      })
    end
  end

  # A code works only for the community it was sent for
  @spec use_transfer_code(User.t(), Common.T.id(), String.t()) ::
          :ok | {:error, :invalid | :expired}
  def use_transfer_code(%User{id: id}, community_id, code) when is_binary(code) do
    case Token.use_code(:transfer_ownership, [user_id: id], code) do
      {:ok, %Token{data: %{"community_id" => ^community_id}}} -> :ok
      {:ok, %Token{}} -> {:error, :invalid}
      error -> error
    end
  end

  defp sign_in_with_email(provider, uid, claims) do
    email = Common.normalize(claims["email"] || "")

    data = %{
      "provider" => Atom.to_string(provider),
      "uid" => uid,
      "name" => claims["name"],
      "username" => claims["preferred_username"]
    }

    case {claims["email_verified"] == true, Accounts.get_user(email: email)} do
      {false, _found} ->
        {:error, :email_not_verified}

      {true, {:ok, user}} ->
        with {:ok, _identity} <- link_identity(user, data), do: signed_in(user, provider)

      {true, {:error, :not_found}} ->
        sign_up(email, data)
    end
  end

  defp sign_up(email, data) do
    with {:ok, token} <- Token.create_random(:sign_up, %{sent_to: email, data: data}) do
      {:sign_up, token}
    end
  end

  defp signed_in(user, method) do
    broadcast(%SignedIn{user_id: user.id, method: method})

    {:ok, user}
  end

  defp link_identity(user, %{"provider" => provider, "uid" => uid}) do
    params = %{user_id: user.id, provider: provider, provider_uid: uid, email: user.email}

    Identity.insert(%Identity{}, params)
  end

  defp link_identity(_user, _data), do: {:ok, nil}

  defp method(%{"provider" => "github"}), do: :github
  defp method(%{"provider" => "google"}), do: :google
  defp method(_data), do: :code

  defp send_email_change_code(user, email) do
    with {:ok, code} <- Token.create_code(:change_email, email, %{user_id: user.id}) do
      ttl = Token.ttl(:change_email)

      broadcast(%EmailChangeCodeRequested{user_id: user.id, email: email, code: code, ttl: ttl})
    end
  end

  defp broadcast(event), do: PubSub.broadcast(@topic, event)
end
