defmodule HearthWeb.EventControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Faker.Lorem
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)
    event = TestUtils.create_random_community_event!(owner, community)

    {:ok, binding()}
  end

  describe "index" do
    test "returns 404 if private", %{conn: conn, owner: owner} do
      private = TestUtils.create_random_community!(owner, visibility: :private)

      assert conn |> get(~p"/api/events?community_id=#{private.id}") |> valid_response(404)
    end

    test "returns 404 if invite only", %{
      conn: conn,
      owner: owner
    } do
      community = TestUtils.create_random_community!(owner, visibility: :invite_only)

      assert conn
             |> auth_conn(TestUtils.register_random_user!())
             |> get(~p"/api/events?community_id=#{community.id}")
             |> valid_response(404)
    end

    test "lists none for someone signed out", %{conn: conn} do
      assert [] = conn |> get(~p"/api/events") |> valid_response(200)
    end

    test "lists the events in the communities joined", %{
      conn: conn,
      owner: owner,
      member: member,
      event: event
    } do
      assert [response] = conn |> auth_conn(member) |> get(~p"/api/events") |> valid_response(200)

      assert response["id"] == event.id
      assert response["interested_ids"] == [owner.id]
      assert response["next_starts_at"]
    end
  end

  describe "create" do
    test "fails for a member without the permission", %{
      conn: conn,
      member: member,
      community: community
    } do
      body = %{
        title: Lorem.sentence(),
        starts_at: DateTime.to_iso8601(DateTime.utc_now()),
        duration_min: 60,
        timezone: "Etc/UTC",
        place: "link"
      }

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/communities/#{community.id}/events", body)
               |> valid_response(403)
    end

    test "fails due to validation", %{conn: conn, owner: owner, community: community} do
      body = %{
        title: "",
        starts_at: DateTime.to_iso8601(DateTime.utc_now()),
        duration_min: 1,
        timezone: "Etc/UTC",
        place: "link"
      }

      assert %{"errors" => errors} =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/events", body)
               |> valid_response(422)

      assert "The title field is required." in errors["title"]
      assert [_message] = errors["duration_min"]
    end

    test "schedules an event", %{conn: conn, owner: owner, community: community} do
      body = %{
        title: Lorem.sentence(),
        starts_at: DateTime.utc_now() |> DateTime.add(1, :day) |> DateTime.to_iso8601(),
        duration_min: 45,
        timezone: "Africa/Lagos",
        repeat: "weekly",
        place: "link",
        url: "https://meet.example.com/hearth"
      }

      assert response =
               conn
               |> auth_conn(owner)
               |> post(~p"/api/communities/#{community.id}/events", body)
               |> valid_response(201)

      assert response["title"] == body.title
      assert response["repeat"] == body.repeat
      assert response["host_id"] == owner.id
    end
  end

  describe "update" do
    test "returns 404 if missing", %{conn: conn, owner: owner} do
      assert conn
             |> auth_conn(owner)
             |> patch(~p"/api/events/#{Common.new_id()}", %{title: Lorem.sentence()})
             |> valid_response(404)
    end

    test "fails if not host or allowed", %{
      conn: conn,
      member: member,
      event: event
    } do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/events/#{event.id}", %{title: Lorem.sentence()})
               |> valid_response(403)
    end

    test "changes an event", %{conn: conn, owner: owner, event: event} do
      body = %{title: Lorem.sentence(), duration_min: 90}

      assert response =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/events/#{event.id}", body)
               |> valid_response(200)

      assert response["title"] == body.title
      assert response["duration_min"] == body.duration_min
    end
  end

  describe "cancel" do
    test "calls off an event and brings it back", %{conn: conn, owner: owner, event: event} do
      assert %{"cancelled_at" => cancelled_at} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/events/#{event.id}/cancelled", %{cancelled: true})
               |> valid_response(200)

      assert cancelled_at

      assert %{"cancelled_at" => nil} =
               conn
               |> auth_conn(owner)
               |> put(~p"/api/events/#{event.id}/cancelled", %{cancelled: false})
               |> valid_response(200)
    end
  end

  describe "delete" do
    test "deletes an event", %{conn: conn, owner: owner, event: event} do
      assert conn |> auth_conn(owner) |> delete(~p"/api/events/#{event.id}") |> response(204)
      assert [] = conn |> auth_conn(owner) |> get(~p"/api/events") |> valid_response(200)
    end
  end

  describe "interest" do
    test "fails for someone outside the community", %{conn: conn, event: event} do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(TestUtils.register_random_user!())
               |> post(~p"/api/events/#{event.id}/interest")
               |> valid_response(403)
    end

    test "marks and takes back interest", %{conn: conn, member: member, event: event} do
      assert %{"on" => true} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/events/#{event.id}/interest")
               |> valid_response(200)

      assert %{"on" => false} =
               conn
               |> auth_conn(member)
               |> post(~p"/api/events/#{event.id}/interest")
               |> valid_response(200)
    end
  end
end
