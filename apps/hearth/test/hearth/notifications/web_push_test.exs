defmodule Hearth.Notifications.WebPushTest do
  use ExUnit.Case, async: true

  import Req.Test

  alias Faker.Internet
  alias Hearth.Notifications.WebPush
  alias Plug.Conn

  setup {Req.Test, :set_req_test_from_context}
  setup {Req.Test, :verify_on_exit!}

  test "generate_vapid_keys/0" do
    assert keys = WebPush.generate_vapid_keys()
    assert is_binary(keys.public)
    assert is_binary(keys.private)
  end

  test "generate_jwt!/2" do
    endpoint = Internet.url()
    keys = WebPush.generate_vapid_keys()

    assert token = WebPush.generate_jwt!(endpoint, keys)
    assert is_binary(token)
  end

  # A real browser's keys, which Hearth keeps flat beside the endpoint
  @subscription_keys %{
    auth: "tBHItJI5svbpez7KI4CCXg==",
    p256dh:
      "BNcRdreALRFXTkOOUHK1EtK2wtaz5Ry4YfYCA_0QTpQtUbVlUls0VJXg7A8u-Ts1XbjhazAkj7I99e8QcYP7DkM="
  }

  test "encrypt/2" do
    message = "Hello world!"

    assert encrypted = WebPush.encrypt_aes128gcm!(message, @subscription_keys)
    assert <<header::binary-size(86), cipher::binary>> = encrypted

    assert <<_salt::binary-size(16), record_size::unsigned-big-integer-size(32), 65,
             _as_pk::binary-size(65)>> =
             header

    assert actual_record_size = min(record_size, byte_size(cipher))
    assert <<_encrypted_data::binary-size(^actual_record_size)>> = cipher
  end

  describe "send/3" do
    test "fails if subscription is expired" do
      subscription = Map.put(@subscription_keys, :endpoint, Internet.url())

      opts = [vapid_keys: WebPush.generate_vapid_keys()]

      expect(WebPush, fn %Conn{method: "POST"} = conn ->
        conn
        |> Conn.put_status(410)
        |> text("push subscription has unsubscribed or expired.\n")
      end)

      assert {:error, :expired} = WebPush.send(subscription, "Hello world!", opts)
    end

    test "fails if payload is too large" do
      subscription = Map.put(@subscription_keys, :endpoint, Internet.url())

      opts = [vapid_keys: WebPush.generate_vapid_keys()]

      expect(WebPush, fn %Conn{method: "POST"} = conn ->
        conn
        |> Conn.put_status(413)
        |> text("payload is too large.\n")
      end)

      assert {:error, :payload_too_large} = WebPush.send(subscription, "Hello world!", opts)
    end

    test "ends up successful" do
      subscription = Map.put(@subscription_keys, :endpoint, Internet.url())

      %{public: public} = keys = WebPush.generate_vapid_keys()
      opts = [vapid_keys: keys]

      # Push services refuse a request without these, while the stub would take anything
      expect(WebPush, fn %Conn{method: "POST"} = conn ->
        ["vapid t=" <> vapid] = Conn.get_req_header(conn, "authorization")
        [_jwt, ^public] = String.split(vapid, ",k=")
        ["application/octet-stream"] = Conn.get_req_header(conn, "content-type")
        ["86400"] = Conn.get_req_header(conn, "ttl")

        # Req.Test takes content-encoding off as if the body were compressed,
        # so the aes128gcm header block stands in for it here
        {:ok, <<_salt::binary-size(16), _size::32, 65, _key::binary-size(65), _rest::binary>>,
         conn} = Conn.read_body(conn)

        text(conn, "")
      end)

      assert :ok = WebPush.send(subscription, "Hello world!", opts)
    end
  end
end
