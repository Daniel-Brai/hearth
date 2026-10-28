defmodule HearthWeb.OAuthController do
  use HearthWeb, :controller

  import HearthWeb.Plugs.RateLimit, only: [rate_limit: 2]

  alias Hearth.Auth
  alias Hearth.Common
  alias Hearth.Notifications
  alias HearthWeb.Endpoint
  alias HearthWeb.RefreshCookie

  @cookie "hearth_oauth"

  rate_limit :start, limit: 20, scale: :timer.minutes(10)

  def start(conn, %{"provider" => provider} = params) do
    return_to = return_to(params["return_to"])

    case Auth.oauth_url(provider, callback_url(provider)) do
      {:ok, %{url: url, session_params: session_params}} ->
        state = %{session_params: session_params, return_to: return_to}

        conn
        |> put_resp_cookie(@cookie, state, [encrypt: true, max_age: 600] ++ cookie_options())
        |> redirect(external: url)

      {:error, _reason} ->
        back(conn, return_to, oauth_error: :unavailable, via: provider)
    end
  end

  def callback(conn, %{"provider" => provider} = params) do
    conn = fetch_cookies(conn, encrypted: [@cookie])

    case conn.cookies[@cookie] do
      %{session_params: session_params, return_to: return_to} ->
        conn = delete_resp_cookie(conn, @cookie, cookie_options())
        result = Auth.oauth_callback(provider, callback_url(provider), params, session_params)

        finish(conn, result, provider, return_to)

      _gone ->
        back(conn, "/signin", oauth_error: :expired, via: provider)
    end
  end

  defp finish(conn, {:ok, user}, provider, return_to) do
    case RefreshCookie.start(conn, user) do
      {:ok, conn} -> back(conn, return_to, oauth: :signed_in)
      {:error, _reason} -> back(conn, return_to, oauth_error: :failed, via: provider)
    end
  end

  defp finish(conn, {:sign_up, token}, provider, return_to) do
    {:ok, details} = Auth.sign_up_details(token)

    back(conn, return_to,
      oauth: :sign_up,
      sign_up_token: token,
      name: details.name,
      username: details.username,
      via: provider
    )
  end

  defp finish(conn, {:error, :email_not_verified}, provider, return_to),
    do: back(conn, return_to, oauth_error: :email_not_verified, via: provider)

  defp finish(conn, {:error, _reason}, provider, return_to),
    do: back(conn, return_to, oauth_error: :failed, via: provider)

  defp back(conn, return_to, fragment) do
    query = fragment |> Common.remove_nil_fields() |> URI.encode_query()

    redirect(conn, external: Notifications.url(return_to) <> "#" <> query)
  end

  defp callback_url(provider),
    do: Endpoint.url() <> "/api/auth/oauth/#{provider}/callback"

  # Browsers read // and /\ as another site so only a plain path may come back
  defp return_to("/" <> rest = path) do
    if String.starts_with?(rest, ~w[/ \\]), do: "/signin", else: path
  end

  defp return_to(_other), do: "/signin"

  # Lax because the provider sends the browser back from its own site
  defp cookie_options do
    secure = Application.fetch_env!(:hearth_web, :secure_cookies)

    [path: "/api/auth/oauth", http_only: true, secure: secure, same_site: "Lax"]
  end
end
