defmodule HearthWeb.AuthController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Auth
  alias Hearth.Media
  alias HearthWeb.Avatars
  alias HearthWeb.ErrorResponse
  alias HearthWeb.Guardian
  alias HearthWeb.Plugs.RequireCustomHeader
  alias HearthWeb.RefreshCookie
  alias Plug.Conn

  @minute :timer.minutes(1)

  plug RequireCustomHeader when action in [:refresh, :sign_out]

  @settings ~w[
    theme
    ui_sounds
    play_sounds
    haptics
    captions_on
    compact_feeds
    sidebar_collapsed
    tour_done
    key_bindings
    notification_prefs
    digest
  ]

  # The web app's shortcut actions, each of which a person may rebind
  @key_actions ~w[
    jump
    jump_quick
    compose
    notifications
    sidebar
    shortcuts
    go_home
    go_events
    go_mod
    go_settings
    go_profile
    feed_next
    feed_prev
    feed_open
    feed_helpful
    post_helpful
    post_reply
    voice_mute
    voice_share
    voice_share_fullscreen
  ]
  tags ["Auth"]

  operation :request_code,
    summary: "Send a sign in code",
    description: "Answers the same whether or not the email has an account",
    request_body: Schema.RequestCodeBody,
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  rate_limit :request_code, limit: 10, scale: 15 * @minute
  rate_limit :request_code, limit: 3, scale: 15 * @minute, by: {:body, :email}

  @validate %{"email" => ~V[required|string|min:3|max:254]}

  def request_code(conn, %{"email" => email}) do
    with :ok <- Auth.request_sign_in_code(email) do
      send_resp(conn, :no_content, "")
    end
  end

  operation :sign_in,
    summary: "Sign in with an email code",
    description: "A new email gets a sign up token instead of a session",
    request_body: Schema.SignInBody,
    responses: [
      ok: {Schema.Session, description: "Signed in"},
      accepted: {Schema.SignUp, description: "No account yet; finish signing up"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  rate_limit :sign_in, limit: 10, scale: 15 * @minute

  @validate %{
    "email" => ~V[required|string|min:3|max:254],
    "code" => ~V[required|string|size:6]
  }

  def sign_in(conn, %{"email" => email, "code" => code}) do
    case Auth.verify_sign_in_code(email, code) do
      {:ok, user} -> start_session(conn, :ok, user)
      {:sign_up, token} -> conn |> put_status(:accepted) |> render(:sign_in, sign_up_token: token)
      {:error, :invalid} -> {:error, :invalid_code}
      {:error, :expired} -> {:error, :expired_code}
    end
  end

  operation :register,
    summary: "Create an account from a sign up token",
    request_body: Schema.RegisterBody,
    responses: [
      created: {Schema.Session, description: "Created and signed in"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  rate_limit :register, limit: 10, scale: 60 * @minute

  @validate %{
    "sign_up_token" => ~V[required|string|min:1|max:64],
    "username" => ~V[required|string|min:3|max:20],
    "display_name" => ~V[string|min:1|max:60]
  }

  def register(conn, params) do
    %{"sign_up_token" => token, "username" => username} = params

    case Auth.register_user(token, username, params["display_name"]) do
      {:ok, user} -> start_session(conn, :created, user)
      {:error, reason} when reason in [:invalid, :expired] -> {:error, :invalid_sign_up_token}
      error -> error
    end
  end

  operation :refresh,
    summary: "Swap the refresh cookie for a new access token",
    description: "Each cookie works once and without one it answers 204",
    security: [%{"refresh_cookie" => []}],
    responses: [
      ok: {Schema.Session, description: "OK"},
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      too_many_requests: %Reference{"$ref": "#/components/responses/too_many_requests"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  rate_limit :refresh, limit: 30, scale: 15 * @minute

  def refresh(conn, _params) do
    case RefreshCookie.fetch(conn) do
      {:ok, session} -> rotate(conn, session)
      {:error, :missing_refresh} -> send_resp(conn, :no_content, "")
    end
  end

  defp rotate(conn, session) do
    case Auth.rotate_session(session, RefreshCookie.meta(conn)) do
      {:ok, user, new_session} ->
        conn
        |> RefreshCookie.put(new_session)
        |> issue(:ok, user)

      {:error, _invalid} ->
        conn
        |> RefreshCookie.delete()
        |> ErrorResponse.halt(:unauthorized, :invalid_refresh, "Sign in again.")
    end
  end

  operation :sign_out,
    summary: "Sign out of this session",
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"}
    ]

  def sign_out(conn, _params) do
    with {:ok, session} <- RefreshCookie.fetch(conn), do: Auth.delete_session(session)

    conn
    |> RefreshCookie.delete()
    |> send_resp(:no_content, "")
  end

  operation :me,
    summary: "Show the signed in person",
    security: [%{"bearer" => []}],
    responses: [
      ok: {Schema.Me, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def me(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn

    render(conn, :me, user: Avatars.put_url(auth))
  end

  operation :update_me,
    summary: "Change the signed in person's profile",
    description: "The photo must be an image they uploaded as an avatar",
    security: [%{"bearer" => []}],
    request_body: Schema.UpdateProfileBody,
    responses: [
      ok: {Schema.Me, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "display_name" => ~V[string|min:1|max:50],
    "bio" => ~V[string|max:300],
    "pronouns" => ~V[string|max:40],
    "location" => ~V[string|max:80],
    "timezone" => ~V[string|max:64],
    "links" => ~V[list|max:20],
    "links.*.url" => ~V[required|string|max:2000],
    "links.*.label" => ~V[string|max:40],
    "privacy" => ~V[map],
    "privacy.show_name" => ~V[boolean],
    "privacy.show_communities" => ~V[allowed:common,everyone,nobody],
    "privacy.presence" => ~V[allowed:everyone,members,nobody],
    "privacy.last_seen" => ~V[allowed:everyone,members,nobody],
    "privacy.avatar" => ~V[allowed:everyone,members,nobody],
    "avatar_id" => ~V[uuid]
  }

  def update_me(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    changes =
      Map.take(params, ~w[display_name bio pronouns location timezone links privacy avatar_id])

    with :ok <- check_avatar(auth, params["avatar_id"]),
         {:ok, user} <- Accounts.update_profile(auth, changes) do
      render(conn, :update_me, user: Avatars.put_url(user))
    end
  end

  operation :request_email_change,
    summary: "Email a code to the address I want to move to",
    description:
      "Needs a sign in from the last 10 minutes and answers the same when the address is taken",
    security: [%{"bearer" => []}],
    request_body: Schema.RequestCodeBody,
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"email" => ~V[required|string|min:3|max:254]}

  rate_limit :request_email_change, limit: 5, scale: 15 * @minute, by: :user

  def request_email_change(%Conn{assigns: %{auth: %{}}} = conn, %{"email" => email}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, session} <- RefreshCookie.fetch(conn),
         true <- Auth.recent_session?(session),
         :ok <- Auth.request_email_change(auth, email) do
      send_resp(conn, :no_content, "")
    else
      {:error, :missing_refresh} -> {:error, :sign_in_again}
      false -> {:error, :sign_in_again}
      error -> error
    end
  end

  operation :confirm_email_change,
    summary: "Move my account to the new address with its code",
    security: [%{"bearer" => []}],
    request_body: Schema.CodeBody,
    responses: [
      ok: {Schema.Me, description: "OK"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"code" => ~V[required|string|size:6]}

  def confirm_email_change(%Conn{assigns: %{auth: %{}}} = conn, %{"code" => code}) do
    %Conn{assigns: %{auth: auth}} = conn

    case Auth.confirm_email_change(auth, code) do
      {:ok, user} -> render(conn, :update_me, user: Avatars.put_url(user))
      {:error, :invalid} -> {:error, :invalid_code}
      {:error, :expired} -> {:error, :expired_code}
      error -> error
    end
  end

  operation :undo_email_change,
    summary: "Move an account back to its old address",
    description:
      "The link in the email changed note carries the token and signs every device out",
    request_body: Schema.TokenBody,
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"token" => ~V[required|string|max:100]}

  rate_limit :undo_email_change, limit: 10, scale: 15 * @minute

  def undo_email_change(conn, %{"token" => token}) do
    case Auth.undo_email_change(token) do
      {:ok, _user} -> send_resp(conn, :no_content, "")
      {:error, reason} when reason in ~w[invalid expired not_found]a -> {:error, :invalid_link}
      error -> error
    end
  end

  operation :update_settings,
    summary: "Change the signed in person's settings",
    security: [%{"bearer" => []}],
    request_body: Schema.UpdateSettingsBody,
    responses: [
      ok: {Schema.Settings, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate Map.merge(
              %{
                "theme" => ~V[allowed:system,light,dark],
                "ui_sounds" => ~V[boolean],
                "play_sounds" => ~V[boolean],
                "haptics" => ~V[boolean],
                "captions_on" => ~V[boolean],
                "compact_feeds" => ~V[boolean],
                "sidebar_collapsed" => ~V[boolean],
                "tour_done" => ~V[boolean],
                "key_bindings" => ~V[map],
                "notification_prefs" => ~V[map],
                "notification_prefs.replies" => ~V[boolean],
                "notification_prefs.mentions" => ~V[boolean],
                "notification_prefs.live" => ~V[boolean],
                "digest" => ~V[allowed:daily,weekly,off]
              },
              Map.new(@key_actions, &{"key_bindings.#{&1}", ~V[string]})
            )

  def update_settings(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn

    changes = Map.take(params, @settings)

    with {:ok, settings} <- Accounts.update_settings(auth, changes) do
      render(conn, :update_settings, settings: settings)
    end
  end

  defp start_session(conn, status, user) do
    with {:ok, conn} <- RefreshCookie.start(conn, user), do: issue(conn, status, user)
  end

  defp issue(conn, status, user) do
    {:ok, token, claims} = Guardian.encode_and_sign(user, %{}, token_type: "access")

    conn
    |> put_status(status)
    |> render(action_name(conn),
      user: Avatars.put_url(user),
      access_token: token,
      expires_in: claims["exp"] - System.os_time(:second)
    )
  end

  defp check_avatar(_auth, nil), do: :ok

  defp check_avatar(auth, id) do
    if Media.avatar?(auth, id), do: :ok, else: {:error, :invalid_avatar}
  end
end
