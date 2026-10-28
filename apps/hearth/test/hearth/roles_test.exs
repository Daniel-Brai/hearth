defmodule Hearth.RolesTest do
  use ExUnit.Case, async: true

  alias Hearth.Roles

  describe "parse!/1" do
    test "fails for a role the release doesn't know" do
      assert_raise ArgumentError, ~r/HEARTH_ROLES has webb/, fn -> Roles.parse!("webb,media") end
    end

    test "fails for an empty list" do
      assert_raise ArgumentError, ~r/HEARTH_ROLES is empty/, fn -> Roles.parse!([]) end
    end

    test "takes every role but rtc when unset" do
      assert Roles.parse!(nil) == ~w[web media ai]a
    end

    test "takes all but rtc when blank" do
      assert Roles.parse!([""]) == ~w[web media ai]a
    end

    test "reads list in fixed order" do
      assert Roles.parse!(" AI, web ,ai") == [:web, :ai]
    end

    test "reads a list from config" do
      assert Roles.parse!(["media"]) == [:media]
    end
  end

  describe "queues/2" do
    test "fails for a queue no role fetches" do
      assert_raise ArgumentError, ~r/:mystery has no role/, fn ->
        Roles.queues([default: 10, mystery: 1], [:web])
      end
    end

    test "keeps the queues the roles fetch" do
      queues = [default: 10, mail: 10, media: 4, video: 1, ai: 4]

      assert Roles.queues(queues, [:media]) == [media: 4, video: 1]
      assert Roles.queues(queues, [:web, :ai]) == [default: 10, mail: 10, ai: 4]
    end

    test "gives every queue a role" do
      queues = :hearth |> Application.fetch_env!(Oban) |> Keyword.fetch!(:queues)

      assert Roles.queues(queues, Roles.default()) == queues
    end
  end

  describe "children/2" do
    test "keeps children for matching roles" do
      entries = [{:everywhere, :all}, {:site, [:web]}, {:models, [:web, :ai]}, {:voice, [:rtc]}]

      assert Roles.children(entries, [:ai]) == [:everywhere, :models]
      assert Roles.children(entries, [:web]) == ~w[everywhere site models]a
    end
  end

  describe "in_cluster/0" do
    test "lists the roles this node announced" do
      assert Roles.in_cluster() == Roles.list()
    end
  end
end
