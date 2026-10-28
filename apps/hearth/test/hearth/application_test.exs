defmodule Hearth.ApplicationTest do
  use ExUnit.Case, async: true

  alias Hearth.Roles
  alias Hearth.TestUtils

  describe "children/1" do
    test "media node starts media queues" do
      children = Hearth.Application.children([:media])

      refute Hearth.Accounts.Supervisor in children
      assert Hearth.Repo in children
      assert TestUtils.oban_queues(children) == [media: 4, video: 1]
    end

    test "ai node starts ai queues" do
      children = Hearth.Application.children([:ai])

      refute Hearth.Chat.Supervisor in children
      assert TestUtils.oban_queues(children) == [ai: 4, transcribe: 1]
    end

    test "rtc node starts voice" do
      children = Hearth.Application.children([:rtc])

      refute Hearth.Chat.Supervisor in children
      assert Hearth.RTC.Supervisor in children
      assert Hearth.Voice.Supervisor in children
      assert TestUtils.oban_queues(children) == []
    end

    test "all roles start everything" do
      children = Hearth.Application.children(Roles.default())

      assert TestUtils.child_names(children) == [
               Hearth.Repo,
               Hearth.PubSub.Supervisor,
               Oban,
               Task,
               DNSCluster,
               :pg,
               Roles,
               Hearth.RTC,
               Hearth.Accounts.Supervisor,
               Hearth.Notifications.Supervisor,
               Hearth.Media.Supervisor,
               Hearth.Forum.Supervisor,
               Hearth.Chat.Supervisor,
               Hearth.Events.Supervisor
             ]

      assert TestUtils.oban_queues(children) ==
               :hearth |> Application.fetch_env!(Oban) |> Keyword.fetch!(:queues)
    end
  end
end
