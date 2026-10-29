defmodule HearthWeb.AuthControllerTest do
  use HearthWeb.ConnCase, async: true
  use Oban.Testing, repo: Hearth.Repo

  alias Faker.Internet
  alias Faker.Lorem
  alias Hearth.Auth
  alias Hearth.Auth.EmailChangeCodeRequested
  alias Hearth.Auth.EmailChangeConfirmed
  alias Hearth.Auth.EmailChangeUndone
  alias Hearth.Auth.SignInCodeRequested
  alias Hearth.Auth.Token
  alias Hearth.Media.Worker.ProcessImage
  alias Hearth.TestUtils

  @cookie "hearth_refresh"

  setup do
    :ok = Auth.subscribe_to_pubsub()
  end

  describe "request_code" do
    test "fails due to validation", %{conn: conn} do
      assert %{"errors" => errors} =
               conn
               |> post(~p"/api/auth/codes", %{})
               |> valid_response(422)

      assert ["The email field is required."] = errors["email"]
    end

    test "fails after three codes to one email", %{conn: conn} do
      email = Internet.email()

      assert conn |> post(~p"/api/auth/codes", %{email: email}) |> response(204)
      assert conn |> post(~p"/api/auth/codes", %{email: email}) |> response(204)
      assert conn |> post(~p"/api/auth/codes", %{email: email}) |> response(204)

      conn = post(conn, ~p"/api/auth/codes", %{email: String.upcase(email)})

      assert %{"code" => "rate_limited"} = valid_response(conn, 429)
    end

    test "sends a code", %{conn: conn} do
      email = Internet.email()

      conn |> post(~p"/api/auth/codes", %{email: email}) |> response(204)

      assert_receive %SignInCodeRequested{email: ^email}
    end
  end

  describe "sign_in" do
    test "fails due to validation", %{conn: conn} do
      assert %{"errors" => errors} =
               conn
               |> post(~p"/api/auth/sessions", %{email: Internet.email(), code: "12ab"})
               |> valid_response(422)

      assert [_pattern] = errors["code"]
    end

    test "fails for a wrong code", %{conn: conn} do
      assert %{"code" => "invalid_code"} =
               conn
               |> post(~p"/api/auth/sessions", %{email: Internet.email(), code: "123456"})
               |> valid_response(400)
    end

    test "gives a new email a sign up token", %{conn: conn} do
      email = Internet.email()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}

      conn = post(conn, ~p"/api/auth/sessions", %{email: email, code: code})

      assert %{"sign_up_token" => _token} = valid_response(conn, 202)
      refute conn.resp_cookies[@cookie]
    end

    test "signs in a known email", %{conn: conn} do
      %{email: email} = user = TestUtils.register_random_user!()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}

      conn = post(conn, ~p"/api/auth/sessions", %{email: email, code: code})

      assert response = valid_response(conn, 200)
      assert response["user"]["id"] == user.id

      assert %{path: "/api/auth", http_only: true, same_site: "Strict"} =
               conn.resp_cookies[@cookie]
    end
  end

  describe "register" do
    test "fails for an unknown sign up token", %{conn: conn} do
      body = %{sign_up_token: "nope", username: TestUtils.random_username()}

      assert %{"code" => "invalid_sign_up_token"} =
               conn
               |> post(~p"/api/auth/users", body)
               |> valid_response(400)
    end

    test "creates the account and signs in", %{conn: conn} do
      email = Internet.email()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}
      {:sign_up, token} = Auth.verify_sign_in_code(email, code)
      body = %{sign_up_token: token, username: TestUtils.random_username()}

      conn = post(conn, ~p"/api/auth/users", body)

      assert response = valid_response(conn, 201)
      assert response["user"]["username"] == body.username
      assert response["user"]["email"] == email
      assert conn.resp_cookies[@cookie]
    end
  end

  describe "refresh" do
    setup do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)

      {:ok, binding()}
    end

    test "fails without the version header", %{session: session} do
      assert %{"code" => "missing_header"} =
               build_conn()
               |> put_req_cookie(@cookie, session)
               |> post(~p"/api/auth/refresh")
               |> json_response(403)
    end

    test "fails the second time a cookie is used", %{conn: conn, session: session} do
      assert conn
             |> put_req_cookie(@cookie, session)
             |> post(~p"/api/auth/refresh")
             |> valid_response(200)

      conn = conn |> put_req_cookie(@cookie, session) |> post(~p"/api/auth/refresh")

      assert %{"code" => "invalid_refresh"} = valid_response(conn, 401)
      assert %{max_age: 0} = conn.resp_cookies[@cookie]
    end

    test "says nothing to refresh without cookie", %{conn: conn} do
      conn = post(conn, ~p"/api/auth/refresh")

      assert conn.status == 204
      refute Map.has_key?(conn.resp_cookies, @cookie)
    end

    test "swaps the cookie for a new access token", %{conn: conn, session: session} do
      refreshed = conn |> put_req_cookie(@cookie, session) |> post(~p"/api/auth/refresh")

      assert response = valid_response(refreshed, 200)
      assert refreshed.resp_cookies[@cookie].value != session

      assert conn
             |> bearer_conn(response["access_token"])
             |> get(~p"/api/auth/me")
             |> valid_response(200)
    end
  end

  describe "sign_out" do
    test "fails without the version header" do
      assert %{"code" => "missing_header"} =
               build_conn()
               |> delete(~p"/api/auth/session")
               |> json_response(403)
    end

    test "ends the session and clears the cookie", %{conn: conn} do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)

      conn = conn |> put_req_cookie(@cookie, session) |> delete(~p"/api/auth/session")

      assert response(conn, 204)
      assert %{max_age: 0} = conn.resp_cookies[@cookie]
      assert {:error, _reason} = Token.find_random(:session, session)
    end
  end

  describe "me" do
    test "fails without signing in", %{conn: conn} do
      assert %{"code" => "missing_token"} =
               conn
               |> get(~p"/api/auth/me")
               |> valid_response(401)
    end

    test "shows the signed in person", %{conn: conn} do
      user = TestUtils.register_random_user!()

      assert response =
               conn
               |> auth_conn(user)
               |> get(~p"/api/auth/me")
               |> valid_response(200)

      assert response["id"] == user.id
    end
  end

  describe "update_settings" do
    setup do
      {:ok, user: TestUtils.register_random_user!()}
    end

    test "fails due to validation", %{conn: conn, user: user} do
      assert %{"errors" => errors} =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me/settings", %{theme: "neon"})
               |> valid_response(422)

      assert [_message] = errors["theme"]
    end

    test "changes only the settings sent", %{conn: conn, user: user} do
      body = %{theme: "dark", notification_prefs: %{replies: false}}

      assert response =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me/settings", body)
               |> valid_response(200)

      assert response["theme"] == body.theme
      assert response["notification_prefs"] == %{"replies" => false}
      assert response["digest"] == "weekly"
    end

    test "saves rebound shortcuts", %{conn: conn, user: user} do
      body = %{key_bindings: %{compose: "c", jump: "mod+p"}}

      assert %{"key_bindings" => key_bindings} =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me/settings", body)
               |> valid_response(200)

      assert key_bindings == %{"compose" => "c", "jump" => "mod+p"}
    end
  end

  describe "update_me" do
    setup do
      {:ok, user: TestUtils.register_random_user!()}
    end

    test "fails with someone else's photo", %{conn: conn, user: user} do
      owner = TestUtils.register_random_user!()
      photo = TestUtils.upload_random_file!(owner, purpose: :avatar)

      assert %{"code" => "invalid_avatar"} =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me", %{avatar_id: photo.id})
               |> valid_response(400)
    end

    test "fails with an image not uploaded as an avatar", %{conn: conn, user: user} do
      image = TestUtils.upload_random_file!(user)

      assert %{"code" => "invalid_avatar"} =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me", %{avatar_id: image.id})
               |> valid_response(400)
    end

    test "fails due to validation", %{conn: conn, user: user} do
      body = %{privacy: %{presence: "friends"}}

      assert %{"errors" => errors} =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me", body)
               |> valid_response(422)

      assert [_message] = errors["privacy.presence"]
    end

    test "sets photo once ready", %{conn: conn, user: user} do
      photo = TestUtils.upload_random_file!(user, width: 400, height: 400, purpose: :avatar)

      assert response =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me", %{avatar_id: photo.id})
               |> valid_response(200)

      assert response["avatar_id"] == photo.id
      assert response["avatar_url"] == nil
      assert :ok = perform_job(ProcessImage, %{media_id: photo.id})

      assert %{"avatar_url" => url} =
               conn |> auth_conn(user) |> get(~p"/api/auth/me") |> valid_response(200)

      assert url =~ "w320.webp"
    end

    test "saves links and privacy", %{conn: conn, user: user} do
      link = %{url: Internet.url(), label: Lorem.word()}

      body = %{
        links: [link],
        privacy: %{show_name: false}
      }

      assert response =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me", body)
               |> valid_response(200)

      assert response["links"] == [%{"url" => link.url, "label" => link.label}]
      assert response["privacy"]["show_name"] == false
    end

    test "changes only fields sent", %{conn: conn, user: user} do
      body = %{bio: Lorem.sentence(), pronouns: "they/them"}

      assert conn |> auth_conn(user) |> patch(~p"/api/auth/me", body) |> valid_response(200)

      assert response =
               conn
               |> auth_conn(user)
               |> patch(~p"/api/auth/me", %{bio: nil})
               |> valid_response(200)

      assert response["bio"] == nil
      assert response["pronouns"] == body.pronouns
    end
  end

  describe "request_email_change" do
    test "fails without a recent sign in", %{conn: conn} do
      user = TestUtils.register_random_user!()

      assert %{"code" => "sign_in_again"} =
               conn
               |> auth_conn(user)
               |> post(~p"/api/auth/me/email", %{email: Internet.email()})
               |> valid_response(400)
    end

    test "sends a code to the new address", %{conn: conn} do
      :ok = Auth.subscribe_to_pubsub()
      %{id: id} = user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)
      email = Internet.email()

      assert conn
             |> auth_conn(user)
             |> put_req_cookie(@cookie, session)
             |> post(~p"/api/auth/me/email", %{email: email})
             |> response(204)

      assert_receive %EmailChangeCodeRequested{user_id: ^id, email: ^email}
    end
  end

  describe "confirm_email_change" do
    test "fails if code is wrong", %{conn: conn} do
      assert %{"code" => "invalid_code"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/auth/me/email/confirm", %{code: "000000"})
               |> valid_response(400)
    end

    test "moves the account to the new address", %{conn: conn} do
      :ok = Auth.subscribe_to_pubsub()
      %{id: id} = user = TestUtils.register_random_user!()
      email = Internet.email()
      :ok = Auth.request_email_change(user, email)
      assert_receive %EmailChangeCodeRequested{user_id: ^id, code: code}

      assert response =
               conn
               |> auth_conn(user)
               |> post(~p"/api/auth/me/email/confirm", %{code: code})
               |> valid_response(200)

      assert response["email"] == email
    end
  end

  describe "undo_email_change" do
    test "fails for an unknown link", %{conn: conn} do
      assert %{"code" => "invalid_link"} =
               conn |> post(~p"/api/auth/email/undo", %{token: "nope"}) |> valid_response(400)
    end

    test "moves the account back", %{conn: conn} do
      :ok = Auth.subscribe_to_pubsub()
      %{id: id} = user = TestUtils.register_random_user!()
      :ok = Auth.request_email_change(user, Internet.email())
      assert_receive %EmailChangeCodeRequested{user_id: ^id, code: code}
      {:ok, _user} = Auth.confirm_email_change(user, code)
      assert_receive %EmailChangeConfirmed{user_id: ^id, undo_token: token}

      assert conn |> post(~p"/api/auth/email/undo", %{token: token}) |> response(204)
      assert_receive %EmailChangeUndone{user_id: ^id, email: email}
      assert email == user.email
    end
  end
end
