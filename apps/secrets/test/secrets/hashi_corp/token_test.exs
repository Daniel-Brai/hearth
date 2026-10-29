defmodule Secrets.HashiCorp.TokenTest do
  use ExUnit.Case, async: true

  alias Secrets.HashiCorp.Secret
  alias Secrets.HashiCorp.Token

  test "keeps the token out of inspect output" do
    token = Token.from!(%{"auth" => %{"client_token" => "s.hidden", "lease_duration" => 60}})

    refute inspect(token) =~ "s.hidden"
  end

  test "keeps secret values out of inspect output" do
    data = %{"data" => %{"url" => "ecto://hidden"}, "metadata" => %{"version" => 1}}
    secret = Secret.from!(%{"data" => data})

    refute inspect(secret) =~ "hidden"
  end
end
