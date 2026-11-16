defmodule HearthWeb.CalendarControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Events
  alias Hearth.Notifications
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, visibility: :public, template: "oss")

    {:ok, binding()}
  end

  describe "show" do
    test "fails for a private community", %{conn: conn, owner: owner} do
      hidden = TestUtils.create_random_community!(owner, visibility: :private)

      assert conn |> get(~p"/calendars/#{hidden.slug <> ".ics"}") |> response(404)
    end

    test "fails without the ics ending", %{conn: conn, community: community} do
      assert conn |> get(~p"/calendars/#{community.slug}") |> response(404)
    end

    test "lists the community's events", %{conn: conn, owner: owner, community: community} do
      event = TestUtils.create_random_community_event!(owner, community)

      body = conn |> get(~p"/calendars/#{community.slug <> ".ics"}") |> response(200)

      assert body =~ "UID:#{event.id}@hearth\r\n"
      assert body =~ "URL:" <> Notifications.url("/c/#{community.slug}/e/")
    end

    test "keeps a repeat in its own time zone", %{
      conn: conn,
      owner: owner,
      community: community
    } do
      _event = TestUtils.create_random_community_event!(owner, community, repeat: :weekly)

      body = conn |> get(~p"/calendars/#{community.slug <> ".ics"}") |> response(200)

      assert body =~ "DTSTART;TZID=Africa/Lagos:"
    end

    test "marks a cancelled event", %{conn: conn, owner: owner, community: community} do
      event = TestUtils.create_random_community_event!(owner, community)
      {:ok, _event} = Events.cancel_event(owner, event)

      body = conn |> get(~p"/calendars/#{community.slug <> ".ics"}") |> response(200)

      assert body =~ "STATUS:CANCELLED"
    end

    test "folds long lines", %{conn: conn, owner: owner, community: community} do
      about = String.duplicate("Bring seeds ", 20)
      _event = TestUtils.create_random_community_event!(owner, community, description: about)

      body = conn |> get(~p"/calendars/#{community.slug <> ".ics"}") |> response(200)

      assert body |> String.split("\r\n") |> Enum.all?(&(byte_size(&1) <= 75))
    end
  end
end
