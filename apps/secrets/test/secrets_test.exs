defmodule SecretsTest do
  # Reading secrets changes the application and OS environment
  use ExUnit.Case, async: false

  import Req.Test

  alias Plug.Conn
  alias Secrets.HashiCorp
  alias Secrets.MissingError

  @names ~w[
    SECRETS_TEST_DATABASE_URL
    SECRETS_TEST_DATABASE_POOL
    SECRETS_TEST_MAIL_KEY
    SECRETS_TEST_PREVIOUS_KEYS
  ]

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  setup %{tmp_dir: tmp_dir} do
    settings = Application.fetch_env!(:secrets, Secrets)
    vault = Application.fetch_env!(:secrets, HashiCorp)

    on_exit(fn ->
      Application.put_env(:secrets, Secrets, settings)
      Application.put_env(:secrets, HashiCorp, vault)
      Enum.each(@names, &System.delete_env/1)
    end)

    jwt_file = Path.join(tmp_dir, "token")
    File.write!(jwt_file, "service-account-jwt\n")

    Application.put_env(:secrets, Secrets, file: "test/fixtures/secrets.yml", env: "staging")
    Application.put_env(:secrets, HashiCorp, Keyword.merge(vault, jwt_file: jwt_file))

    :ok
  end

  describe "inject!/0" do
    @describetag :tmp_dir

    test "fails when Vault refuses the sign in" do
      stub(HashiCorp, fn conn ->
        conn |> Conn.put_status(403) |> json(%{errors: ["permission denied"]})
      end)

      assert_raise HashiCorp.Error, ~r/403 signing in: permission denied/, fn ->
        Secrets.inject!()
      end
    end

    test "fails when a secret doesn't exist" do
      stub(HashiCorp, fn
        %Conn{method: "POST"} = conn ->
          json(conn, %{auth: %{client_token: "s.token", lease_duration: 60}})

        conn ->
          conn |> Conn.put_status(404) |> json(%{errors: []})
      end)

      assert_raise HashiCorp.Error, ~r/404 reading hearth\/staging\//, fn -> Secrets.inject!() end
    end

    test "fails for missing variables" do
      stub(HashiCorp, fn
        %Conn{method: "POST"} = conn ->
          json(conn, %{auth: %{client_token: "s.token", lease_duration: 60}})

        %Conn{request_path: "/v1/hearth/data/staging/database"} = conn ->
          json(conn, %{data: %{data: %{"url" => "ecto://db"}, metadata: %{version: 1}}})

        %Conn{request_path: "/v1/hearth/data/staging/mail"} = conn ->
          json(conn, %{data: %{data: %{"api_key" => ""}, metadata: %{version: 2}}})

        %Conn{request_path: "/v1/hearth/data/staging/encryption"} = conn ->
          json(conn, %{data: %{data: %{}, metadata: %{version: 1}}})
      end)

      error = assert_raise MissingError, fn -> Secrets.inject!() end

      assert error.names == ~w[SECRETS_TEST_DATABASE_POOL SECRETS_TEST_MAIL_KEY]
      refute System.get_env("SECRETS_TEST_DATABASE_URL")
    end

    test "sets nothing without a secrets file" do
      Application.put_env(:secrets, Secrets, file: nil, env: "staging")

      assert Secrets.inject!() == 0
    end

    test "reads each secret once" do
      expect(HashiCorp, 4, fn
        %Conn{method: "POST", request_path: "/v1/auth/kubernetes/login"} = conn ->
          {:ok, body, conn} = Conn.read_body(conn)
          assert %{"role" => "hearth", "jwt" => "service-account-jwt"} = Jason.decode!(body)

          json(conn, %{auth: %{client_token: "s.token", lease_duration: 60}})

        %Conn{method: "GET", request_path: "/v1/hearth/data/staging/database"} = conn ->
          assert Conn.get_req_header(conn, "x-vault-token") == ["s.token"]

          data = %{"url" => "ecto://db", "pool_size" => "20"}
          json(conn, %{data: %{data: data, metadata: %{version: 3}}})

        %Conn{method: "GET", request_path: "/v1/hearth/data/staging/mail"} = conn ->
          json(conn, %{data: %{data: %{"api_key" => "mail-key"}, metadata: %{version: 1}}})

        %Conn{method: "GET", request_path: "/v1/hearth/data/staging/encryption"} = conn ->
          json(conn, %{data: %{data: %{}, metadata: %{version: 1}}})
      end)

      assert Secrets.inject!() == 3
      assert System.get_env("SECRETS_TEST_DATABASE_URL") == "ecto://db"
      assert System.get_env("SECRETS_TEST_DATABASE_POOL") == "20"
      assert System.get_env("SECRETS_TEST_MAIL_KEY") == "mail-key"
      refute System.get_env("SECRETS_TEST_PREVIOUS_KEYS")
    end

    test "signs in with an AppRole read from files", %{tmp_dir: tmp_dir} do
      role_id_file = Path.join(tmp_dir, "role-id")
      secret_id_file = Path.join(tmp_dir, "secret-id")
      File.write!(role_id_file, "role\n")
      File.write!(secret_id_file, "secret\n")

      vault = Application.fetch_env!(:secrets, HashiCorp)

      Application.put_env(
        :secrets,
        HashiCorp,
        Keyword.merge(vault,
          auth: "approle",
          role_id_file: role_id_file,
          secret_id_file: secret_id_file
        )
      )

      stub(HashiCorp, fn
        %Conn{method: "POST", request_path: "/v1/auth/approle/login"} = conn ->
          {:ok, body, conn} = Conn.read_body(conn)
          assert %{"role_id" => "role", "secret_id" => "secret"} = Jason.decode!(body)

          json(conn, %{auth: %{client_token: "s.token", lease_duration: 60}})

        conn ->
          data = %{"url" => "u", "pool_size" => "1", "api_key" => "k", "previous_keys" => "p"}
          json(conn, %{data: %{data: data, metadata: %{version: 1}}})
      end)

      assert Secrets.inject!() == 4
    end

    test "uses a given token without signing in" do
      vault = Application.fetch_env!(:secrets, HashiCorp)

      Application.put_env(
        :secrets,
        HashiCorp,
        Keyword.merge(vault, auth: "token", token: "s.root")
      )

      stub(HashiCorp, fn %Conn{method: "GET"} = conn ->
        assert Conn.get_req_header(conn, "x-vault-token") == ["s.root"]

        data = %{"url" => "u", "pool_size" => "1", "api_key" => "k"}
        json(conn, %{data: %{data: data, metadata: %{version: 1}}})
      end)

      assert Secrets.inject!() == 3
    end
  end
end
