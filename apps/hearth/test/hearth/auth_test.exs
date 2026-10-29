defmodule Hearth.AuthTest do
  use Hearth.DataCase, async: true

  alias Faker.Internet
  alias Faker.Person
  alias Hearth.Accounts
  alias Hearth.Auth
  alias Hearth.Auth.EmailChangeBlocked
  alias Hearth.Auth.EmailChangeCodeRequested
  alias Hearth.Auth.EmailChangeConfirmed
  alias Hearth.Auth.EmailChangeUndone
  alias Hearth.Auth.Identity
  alias Hearth.Auth.SignedIn
  alias Hearth.Auth.SignInCodeRequested
  alias Hearth.Auth.Token
  alias Hearth.TestUtils

  setup do
    :ok = Auth.subscribe_to_pubsub()
  end

  describe "request_sign_in_code/1" do
    test "fails if email is invalid" do
      assert {:error, changeset} = Auth.request_sign_in_code("not-an-email")
      assert %{email: ["is not a valid email"]} = errors_on(changeset)
      refute_receive %SignInCodeRequested{email: "not-an-email"}
    end

    test "sends code to new email" do
      email = Internet.email()

      assert :ok = email |> String.upcase() |> Auth.request_sign_in_code()
      assert_receive %SignInCodeRequested{email: ^email}
    end

    test "sends code to registered email" do
      %{email: email} = TestUtils.register_random_user!()

      assert :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email}
    end
  end

  describe "verify_sign_in_code/2" do
    test "fails if no code was sent" do
      assert {:error, :invalid} = Auth.verify_sign_in_code(Internet.email(), "123456")
    end

    test "fails if code is wrong" do
      email = Internet.email()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}

      assert {:error, :invalid} = Auth.verify_sign_in_code(email, "wrong")
      assert {:sign_up, _token} = Auth.verify_sign_in_code(email, code)
    end

    test "fails after five wrong codes" do
      email = Internet.email()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}

      :ok = TestUtils.verify_wrong_codes!(email, 5)

      assert {:error, :invalid} = Auth.verify_sign_in_code(email, code)
    end

    test "fails if code expired" do
      email = Internet.email()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}

      :ok = TestUtils.update_rows!(Token, [sent_to: email], expires_at: TestUtils.minutes_ago(1))

      assert {:error, :expired} = Auth.verify_sign_in_code(email, code)
    end

    test "returns sign up token for new email" do
      email = Internet.email()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}

      assert {:sign_up, _token} = Auth.verify_sign_in_code(email, code)
      assert {:error, :invalid} = Auth.verify_sign_in_code(email, code)
    end

    test "returns user for registered email" do
      %{id: id, email: email} = TestUtils.register_random_user!()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}

      assert {:ok, %{id: ^id}} = Auth.verify_sign_in_code(email, code)
      assert_receive %SignedIn{user_id: ^id, method: :code}
    end
  end

  describe "register_user/3" do
    setup do
      email = Internet.email()
      :ok = Auth.request_sign_in_code(email)
      assert_receive %SignInCodeRequested{email: ^email, code: code}
      {:sign_up, token} = Auth.verify_sign_in_code(email, code)

      {:ok, binding()}
    end

    test "fails if token is invalid" do
      assert {:error, :invalid} = Auth.register_user("nope", TestUtils.random_username())
    end

    test "fails if username is invalid", %{token: token} do
      assert {:error, changeset} = Auth.register_user(token, "no spaces")
      assert %{username: [_message]} = errors_on(changeset)
    end

    test "register user", %{email: email, token: token} do
      username = TestUtils.random_username()
      display_name = Person.name()

      assert {:ok, user} = Auth.register_user(token, username, display_name)
      assert %{email: ^email, username: ^username, display_name: ^display_name} = user
      assert %DateTime{} = user.email_confirmed_at
      assert {:error, :invalid} = Auth.register_user(token, TestUtils.random_username())
    end
  end

  describe "sign_up_details/1" do
    test "fails if token is invalid" do
      assert {:error, :invalid} = Auth.sign_up_details("nope")
    end

    test "returns provider name and username" do
      claims = %{
        "sub" => "11",
        "email" => Internet.email(),
        "email_verified" => true,
        "name" => Person.name(),
        "preferred_username" => TestUtils.random_username()
      }

      {:sign_up, token} = Auth.sign_in_with_identity(:github, claims)

      assert {:ok, %{name: name, username: username}} = Auth.sign_up_details(token)
      assert name == claims["name"]
      assert username == claims["preferred_username"]
    end
  end

  describe "sign_in_with_identity/2" do
    test "fails if email is not verified" do
      claims = %{"sub" => "1", "email" => Internet.email(), "email_verified" => false}

      assert {:error, :email_not_verified} = Auth.sign_in_with_identity(:github, claims)
    end

    test "returns sign up token for new email" do
      claims = %{
        "sub" => "42",
        "email" => Internet.email(),
        "email_verified" => true,
        "name" => Person.name()
      }

      assert {:sign_up, token} = Auth.sign_in_with_identity(:github, claims)
      assert {:ok, %{id: id}} = Auth.register_user(token, TestUtils.random_username())
      assert %Identity{user_id: ^id} = Identity.get(provider: :github, provider_uid: "42")
    end

    test "links identity to registered email" do
      %{id: id, email: email} = TestUtils.register_random_user!()
      claims = %{"sub" => 7, "email" => email, "email_verified" => true}

      assert {:ok, %{id: ^id}} = Auth.sign_in_with_identity(:google, claims)
      assert %Identity{user_id: ^id} = Identity.get(provider: :google, provider_uid: "7")
      assert_receive %SignedIn{user_id: ^id, method: :google}
    end

    test "returns user for linked identity" do
      %{id: id, email: email} = user = TestUtils.register_random_user!()
      claims = %{"sub" => "9", "email" => email, "email_verified" => true}
      {:ok, _user} = Auth.sign_in_with_identity(:github, claims)
      {:ok, _user} = Accounts.change_email(user, Internet.email())

      assert {:ok, %{id: ^id}} = Auth.sign_in_with_identity(:github, claims)
    end
  end

  describe "oauth_url/2" do
    test "fails if provider is not set up" do
      assert {:error, :not_found} = Auth.oauth_url("google", "http://localhost/callback")
      assert {:error, :not_found} = Auth.oauth_url("myspace", "http://localhost/callback")
    end

    test "returns url" do
      assert {:ok, %{url: url, session_params: %{}}} =
               Auth.oauth_url("github", "http://localhost/callback")

      assert String.starts_with?(url, "https://github.com/login/oauth/authorize")
    end
  end

  describe "create_session/2" do
    test "stores the address it signed in from sealed" do
      user = TestUtils.register_random_user!()
      ip = Internet.ip_v4_address()
      {:ok, _session} = Auth.create_session(user, %{ip: ip})
      token = Token.get(user_id: user.id)

      assert token.ip == ip
      refute TestUtils.stored_value!(Token, token.id, :ip) =~ ip
    end
  end

  describe "recent_session?/1" do
    test "fails if session is old" do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)

      inserted_at = TestUtils.minutes_ago(11)
      :ok = TestUtils.update_rows!(Token, [user_id: user.id], inserted_at: inserted_at)

      refute Auth.recent_session?(session)
    end

    test "returns true for new session" do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)

      assert Auth.recent_session?(session)
    end
  end

  describe "rotate_session/2" do
    test "fails if session is unknown" do
      assert {:error, :invalid} = Auth.rotate_session("nope")
    end

    test "fails if session expired" do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)

      expires_at = TestUtils.minutes_ago(1)
      :ok = TestUtils.update_rows!(Token, [user_id: user.id], expires_at: expires_at)

      assert {:error, :expired} = Auth.rotate_session(session)
    end

    test "fails if session used twice" do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)
      {:ok, _user, _new_session} = Auth.rotate_session(session)

      assert {:error, :invalid} = Auth.rotate_session(session)
    end

    test "swaps the session for a new one" do
      %{id: id} = user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)

      assert {:ok, %{id: ^id}, new_session} =
               Auth.rotate_session(session, %{ip: Internet.ip_v4_address()})

      assert {:ok, %{user_id: ^id}} = Token.find_random(:session, new_session)
      assert {:error, _reason} = Token.find_random(:session, session)
    end
  end

  describe "delete_session/1" do
    test "delete session" do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)
      {:ok, other_session} = Auth.create_session(user)

      assert :ok = Auth.delete_session(session)
      assert {:error, _reason} = Token.find_random(:session, session)
      assert {:ok, _token} = Token.find_random(:session, other_session)
    end
  end

  describe "delete_all_sessions/1" do
    test "delete all sessions" do
      user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)
      {:ok, other_session} = Auth.create_session(user)

      assert :ok = Auth.delete_all_sessions(user)
      assert {:error, _reason} = Token.find_random(:session, session)
      assert {:error, _reason} = Token.find_random(:session, other_session)
    end
  end

  describe "request_email_change/2" do
    test "fails if email is invalid" do
      user = TestUtils.register_random_user!()

      assert {:error, changeset} = Auth.request_email_change(user, "not-an-email")
      assert %{email: ["is not a valid email"]} = errors_on(changeset)
    end

    test "fails if email is the current one" do
      user = TestUtils.register_random_user!()

      assert {:error, changeset} = Auth.request_email_change(user, user.email)
      assert %{email: ["is already your email"]} = errors_on(changeset)
    end

    test "sends note if email is taken" do
      user = TestUtils.register_random_user!()
      %{email: email} = TestUtils.register_random_user!()

      assert :ok = Auth.request_email_change(user, email)
      assert_receive %EmailChangeBlocked{email: ^email}
      refute_receive %EmailChangeCodeRequested{email: ^email}
    end

    test "sends code" do
      %{id: id} = user = TestUtils.register_random_user!()
      email = Internet.email()

      assert :ok = Auth.request_email_change(user, email)
      assert_receive %EmailChangeCodeRequested{user_id: ^id, email: ^email, ttl: 15}
    end
  end

  describe "confirm_email_change/2" do
    setup do
      user = TestUtils.register_random_user!()
      email = Internet.email()
      :ok = Auth.request_email_change(user, email)
      assert_receive %EmailChangeCodeRequested{email: ^email, code: code}

      {:ok, binding()}
    end

    test "fails if code is wrong", %{user: user} do
      assert {:error, :invalid} = Auth.confirm_email_change(user, "wrong")
    end

    test "change email", %{user: user, email: email, code: code} do
      %{id: id, email: old_email} = user

      assert {:ok, %{email: ^email}} = Auth.confirm_email_change(user, code)

      assert_receive %EmailChangeConfirmed{
        user_id: ^id,
        old_email: ^old_email,
        new_email: ^email,
        ttl: 10_080
      }
    end
  end

  describe "undo_email_change/1" do
    test "fails if token is invalid" do
      assert {:error, :invalid} = Auth.undo_email_change("nope")
    end

    test "undo email change" do
      %{id: id, email: old_email} = user = TestUtils.register_random_user!()
      {:ok, session} = Auth.create_session(user)

      email = Internet.email()

      :ok = Auth.request_email_change(user, email)
      assert_receive %EmailChangeCodeRequested{email: ^email, code: code}

      {:ok, _user} = Auth.confirm_email_change(user, code)
      assert_receive %EmailChangeConfirmed{user_id: ^id, undo_token: undo_token}

      assert {:ok, %{email: ^old_email}} = Auth.undo_email_change(undo_token)
      assert_receive %EmailChangeUndone{user_id: ^id, email: ^old_email}
      assert {:error, _reason} = Token.find_random(:session, session)
      assert {:error, :invalid} = Auth.undo_email_change(undo_token)
    end
  end
end
