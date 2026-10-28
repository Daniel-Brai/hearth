defmodule HearthWeb.Plugs.AuthenticateTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.TestUtils
  alias JOSE.JWK
  alias JOSE.JWS
  alias JOSE.JWT

  setup do
    {:ok, user: TestUtils.register_random_user!()}
  end

  describe "call/2" do
    test "fails without a token where one is needed", %{conn: conn} do
      assert %{"code" => "missing_token"} =
               conn
               |> get(~p"/api/auth/me")
               |> valid_response(401)
    end

    test "fails for a token that isn't a JWT", %{conn: conn} do
      assert %{"code" => "invalid_token"} =
               conn
               |> bearer_conn("nope")
               |> get(~p"/api/auth/me")
               |> json_response(401)
    end

    test "fails for a token with no signature", %{conn: conn, user: user} do
      parts = [%{"alg" => "none", "typ" => "JWT"}, access_claims(user)]

      unsigned =
        Enum.map_join(parts, ".", &(&1 |> Jason.encode!() |> Base.url_encode64(padding: false)))

      assert %{"code" => "invalid_token"} =
               conn
               |> bearer_conn(unsigned <> ".")
               |> get(~p"/api/auth/me")
               |> json_response(401)
    end

    test "fails for a token signed with a shared secret", %{conn: conn, user: user} do
      jwk = JWK.from_oct("not the signing key")

      {_jws, token} =
        jwk |> JWT.sign(%{"alg" => "HS256"}, access_claims(user)) |> JWS.compact()

      assert %{"code" => "invalid_token"} =
               conn
               |> bearer_conn(token)
               |> get(~p"/api/auth/me")
               |> json_response(401)
    end

    test "fails for a token from an unknown key", %{conn: conn, user: user} do
      {_kty, pem} = {:ec, "P-256"} |> JWK.generate_key() |> JWK.to_pem()
      token = sign_token(access_claims(user), pem)

      assert %{"code" => "invalid_token"} =
               conn
               |> bearer_conn(token)
               |> get(~p"/api/auth/me")
               |> json_response(401)
    end

    test "fails for a token for another audience", %{conn: conn, user: user} do
      token = sign_token(access_claims(user, %{"aud" => "elsewhere"}), previous_key_pem())

      assert %{"code" => "invalid_token"} =
               conn
               |> bearer_conn(token)
               |> get(~p"/api/auth/me")
               |> json_response(401)
    end

    test "fails for a token without an expiry", %{conn: conn, user: user} do
      claims = user |> access_claims() |> Map.delete("exp")
      token = sign_token(claims, previous_key_pem())

      assert %{"code" => "invalid_token"} =
               conn
               |> bearer_conn(token)
               |> get(~p"/api/auth/me")
               |> json_response(401)
    end

    test "fails for an expired token", %{conn: conn, user: user} do
      past = System.os_time(:second) - 60
      token = sign_token(access_claims(user, %{"exp" => past}), previous_key_pem())

      assert %{"code" => "invalid_token"} =
               conn
               |> bearer_conn(token)
               |> get(~p"/api/auth/me")
               |> json_response(401)
    end

    test "fails for a token issued in the future", %{conn: conn, user: user} do
      future = System.os_time(:second) + 600
      token = sign_token(access_claims(user, %{"iat" => future}), previous_key_pem())

      assert %{"code" => "invalid_token"} =
               conn
               |> bearer_conn(token)
               |> get(~p"/api/auth/me")
               |> json_response(401)
    end

    test "accepts a token from the previous key", %{conn: conn, user: user} do
      token = sign_token(access_claims(user), previous_key_pem())

      conn = conn |> bearer_conn(token) |> get(~p"/api/auth/me")

      assert %{"id" => id} = valid_response(conn, 200)
      assert id == user.id
    end

    test "signs in with a current token", %{conn: conn, user: user} do
      conn = conn |> auth_conn(user) |> get(~p"/api/auth/me")

      assert %{"username" => username} = valid_response(conn, 200)
      assert username == user.username
    end
  end
end
