defmodule Hearth.VaultTest do
  use ExUnit.Case, async: false

  alias Faker.Internet
  alias Faker.Lorem
  alias Hearth.TestUtils
  alias Hearth.Vault

  setup do
    on_exit(fn -> :ok = Vault.load!() end)

    {:ok, previous: Application.fetch_env!(:hearth, Vault)}
  end

  describe "load!/0" do
    test "fails for a key that isn't 32 bytes" do
      :ok = TestUtils.merge_env(Vault, key: Base.encode64("too short"))

      assert_raise ArgumentError, fn -> Vault.load!() end
    end
  end

  describe "encrypt/1" do
    test "seals the same text differently each time" do
      text = Lorem.sentence()

      refute Vault.encrypt(text) == Vault.encrypt(text)
      refute Vault.encrypt(text) =~ text
    end
  end

  describe "decrypt/1" do
    test "fails for a value that was changed" do
      sealed = Vault.encrypt(Lorem.sentence())
      <<head::binary-33, byte, rest::binary>> = sealed

      assert :error = Vault.decrypt(<<head::binary, Bitwise.bxor(byte, 1), rest::binary>>)
    end

    test "fails for a value sealed with an unknown key" do
      sealed = Vault.encrypt(Lorem.sentence())
      :ok = TestUtils.merge_env(Vault, key: TestUtils.random_key())
      :ok = Vault.load!()

      assert :error = Vault.decrypt(sealed)
    end

    test "opens data from old key", %{previous: previous} do
      text = Lorem.sentence()
      sealed = Vault.encrypt(text)

      key = TestUtils.random_key()
      :ok = TestUtils.merge_env(Vault, key: key, previous_keys: previous[:key])
      :ok = Vault.load!()

      assert {:ok, ^text} = Vault.decrypt(sealed)
      refute binary_part(Vault.encrypt(text), 1, 4) == binary_part(sealed, 1, 4)
    end

    test "opens what it sealed" do
      text = Lorem.sentence()

      assert {:ok, ^text} = text |> Vault.encrypt() |> Vault.decrypt()
    end
  end

  describe "hash/1" do
    test "gives each value its own digest" do
      refute Vault.hash(Internet.email()) == Vault.hash(Internet.email())
    end

    test "keeps the same digest after the key changes" do
      email = Internet.email()
      digest = Vault.hash(email)
      :ok = TestUtils.merge_env(Vault, key: TestUtils.random_key())
      :ok = Vault.load!()

      assert Vault.hash(email) == digest
    end
  end
end
