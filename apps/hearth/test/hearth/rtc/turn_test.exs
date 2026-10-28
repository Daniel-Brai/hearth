defmodule Hearth.RTC.TurnTest do
  use ExUnit.Case, async: true

  alias Hearth.Common
  alias Hearth.RTC.Turn

  describe "credentials/4" do
    test "signs the expiry and id with the secret" do
      assert {"1700021600:alice", "aonDLPDw0TXo+i6Ds/clXYd7Cs8="} =
               Turn.credentials("alice", "north", 21_600, 1_700_000_000)
    end
  end

  describe "ice_servers/2" do
    test "gives none without a secret" do
      assert [] = Turn.ice_servers(Common.new_id(), turn_url: "turn.example.com")
    end

    test "gives none without a url" do
      assert [] = Turn.ice_servers(Common.new_id(), turn_secret: "north")
    end

    test "turns a host into UDP and TCP on 3478" do
      user_id = Common.new_id()
      config = [turn_url: "turn.example.com", turn_secret: "north", turn_ttl: 21_600]

      assert [%{urls: urls, username: username, credential: credential}] =
               Turn.ice_servers(user_id, config)

      assert urls ==
               ~w[
                 turn:turn.example.com:3478?transport=udp
                 turn:turn.example.com:3478?transport=tcp
               ]

      assert [expires, ^user_id] = String.split(username, ":")
      assert String.to_integer(expires) > System.os_time(:second) + 21_000
      assert byte_size(Base.decode64!(credential)) == 20
    end

    test "keeps full urls" do
      config = [
        turn_url: "turns:turn.example.com:5349, turn:turn.example.com:3478",
        turn_secret: "north",
        turn_ttl: 60
      ]

      assert [%{urls: ["turns:turn.example.com:5349", "turn:turn.example.com:3478"]}] =
               Turn.ice_servers(Common.new_id(), config)
    end
  end
end
