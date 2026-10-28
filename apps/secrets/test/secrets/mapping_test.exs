defmodule Secrets.MappingTest do
  use ExUnit.Case, async: true

  alias Secrets.Mapping

  describe "read!/2" do
    test "fails for a line without a key" do
      assert_raise ArgumentError, ~r/SECRETS_TEST_DATABASE_URL in the secrets file/, fn ->
        Mapping.read!("test/fixtures/no_key.yml", "staging")
      end
    end

    test "reads variables with environment path" do
      assert [
               %Mapping{name: "SECRETS_TEST_DATABASE_POOL", path: "hearth/prod/database"},
               %Mapping{name: "SECRETS_TEST_DATABASE_URL", key: "url"},
               %Mapping{name: "SECRETS_TEST_MAIL_KEY", path: "hearth/prod/mail", optional: false},
               %Mapping{name: "SECRETS_TEST_PREVIOUS_KEYS", optional: true}
             ] = Mapping.read!("test/fixtures/secrets.yml", "prod")
    end
  end
end
