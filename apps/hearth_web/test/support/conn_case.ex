defmodule HearthWeb.ConnCase do
  use ExUnit.CaseTemplate

  alias Hearth.Common
  alias Hearth.DataCase
  alias HearthWeb.OpenAPISpec
  alias HearthWeb.Plugs.ApiVersion
  alias HearthWeb.Schema.Event
  alias Plug.Conn

  using do
    quote do
      @endpoint HearthWeb.Endpoint

      use HearthWeb, :verified_routes

      import Plug.Conn
      import Phoenix.ConnTest
      import HearthWeb.ConnCase
    end
  end

  # Every conn is sent as the web app sends it, as JSON with the API version
  # it pins.
  setup tags do
    DataCase.setup_sandbox(tags)

    conn =
      Phoenix.ConnTest.build_conn()
      |> Conn.put_req_header("accept", "application/json")
      |> Conn.put_req_header("content-type", "application/json")
      |> Conn.put_req_header("hearth-version", ApiVersion.latest())

    {:ok, conn: conn}
  end

  def auth_conn(conn, user) do
    {:ok, token, _claims} = HearthWeb.Guardian.encode_and_sign(user, %{}, token_type: "access")

    bearer_conn(conn, token)
  end

  def bearer_conn(conn, token) do
    Conn.put_req_header(conn, "authorization", "Bearer " <> token)
  end

  def valid_response(conn, status) do
    Oaskit.Test.valid_response(OpenAPISpec, conn, status)
  end

  def sign_token(claims, pem, headers \\ %{}) do
    jwk = JOSE.JWK.from_pem(pem)
    kid = jwk |> JOSE.JWK.to_public() |> JOSE.JWK.thumbprint()
    jws = Map.merge(%{"alg" => "ES256", "kid" => kid}, headers)

    {_jws, token} = jwk |> JOSE.JWT.sign(jws, claims) |> JOSE.JWS.compact()

    token
  end

  def unsigned_token(claims) do
    Enum.map_join([%{"alg" => "none", "typ" => "JWT"}, claims], ".", fn part ->
      part |> Jason.encode!() |> Base.url_encode64(padding: false)
    end)
  end

  def access_claims(user, extra \\ %{}) do
    now = System.os_time(:second)

    Map.merge(
      %{
        "iss" => HearthWeb.Guardian.config(:issuer),
        "aud" => HearthWeb.Guardian.audience(),
        "sub" => "user:" <> user.id,
        "typ" => "access",
        "iat" => now,
        "exp" => now + 900,
        "jti" => Common.new_id()
      },
      extra
    )
  end

  def previous_key_pem do
    __DIR__
    |> Path.join("fixtures/previous_jwt_key.pem")
    |> File.read!()
  end

  def events_with_undescribed_fields, do: Enum.reject(Event.all(), &describes_what_it_sends?/1)

  def events_with_other_names do
    for schema <- Event.all(),
        event = struct(schema.event()),
        schema.json_schema().title != schema.event().broadcast_as(event),
        do: schema
  end

  defp describes_what_it_sends?(schema) do
    sent =
      schema.event() |> struct() |> schema.event().broadcast_with() |> Map.keys() |> Enum.sort()

    %{properties: properties, required: required} = schema.json_schema()

    properties |> Map.keys() |> Enum.sort() == sent and Enum.sort(required) == sent
  end
end
