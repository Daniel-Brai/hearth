defmodule HearthWeb.RecordingControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Common
  alias Hearth.TestUtils
  alias Hearth.Voice.Recording

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)
    outsider = TestUtils.register_random_user!()
    session = TestUtils.insert_random_voice_session!(community)
    recording = TestUtils.record_random_session!(session, [{owner.id, :audio, 0, 1}], 1)

    {:ok, binding()}
  end

  describe "room_index" do
    test "fails for someone outside the community", %{
      conn: conn,
      outsider: outsider,
      session: session
    } do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(outsider)
               |> get(~p"/api/rooms/#{session.room_id}/recordings")
               |> valid_response(403)
    end

    test "fails for a missing room", %{conn: conn, member: member} do
      assert %{"code" => "not_found"} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/rooms/#{Common.new_id()}/recordings")
               |> valid_response(404)
    end

    test "lists the room's recordings", %{
      conn: conn,
      member: member,
      session: session,
      recording: recording
    } do
      assert %{"data" => [%{"status" => "processing", "video_url" => nil} = listed]} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/rooms/#{session.room_id}/recordings")
               |> valid_response(200)

      assert listed["id"] == recording.id
    end
  end

  describe "event_index" do
    test "fails for a missing event", %{conn: conn, member: member} do
      assert %{"code" => "not_found"} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/events/#{Common.new_id()}/recordings")
               |> valid_response(404)
    end

    test "lists the event's recordings", %{conn: conn, owner: owner, community: community} do
      event = TestUtils.create_random_community_event!(owner, community)

      assert %{"data" => []} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/events/#{event.id}/recordings")
               |> valid_response(200)
    end
  end

  describe "post_index" do
    test "fails for a missing post", %{conn: conn, member: member} do
      assert %{"code" => "not_found"} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/posts/#{Common.new_id()}/recordings")
               |> valid_response(404)
    end
  end

  describe "show" do
    test "fails for someone outside the community", %{
      conn: conn,
      outsider: outsider,
      recording: recording
    } do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(outsider)
               |> get(~p"/api/recordings/#{recording.id}")
               |> valid_response(403)
    end

    test "shows a ready recording with its addresses", %{
      conn: conn,
      member: member,
      owner: owner,
      recording: recording
    } do
      speaker = %Recording.Speaker{user_id: owner.id, key: Recording.key(recording, "a.m4a")}

      changes = [
        status: :ready,
        video_key: Recording.key(recording, "video.mp4"),
        poster_key: Recording.key(recording, "poster.webp"),
        speakers: [speaker]
      ]

      :ok = TestUtils.update_rows!(Recording, [id: recording.id], changes)

      assert %{"status" => "ready", "video_url" => "http" <> _video} =
               response =
               conn
               |> auth_conn(member)
               |> get(~p"/api/recordings/#{recording.id}")
               |> valid_response(200)

      assert [listed] = response["speakers"]
      assert listed["user_id"] == owner.id
    end
  end

  describe "update" do
    test "fails for someone who did not record it", %{
      conn: conn,
      member: member,
      recording: recording
    } do
      body = %{title: Faker.Lorem.sentence()}

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> patch(~p"/api/recordings/#{recording.id}", body)
               |> valid_response(403)
    end

    test "rename recording", %{conn: conn, owner: owner, recording: recording} do
      body = %{title: Faker.Lorem.sentence()}

      assert %{"title" => title} =
               conn
               |> auth_conn(owner)
               |> patch(~p"/api/recordings/#{recording.id}", body)
               |> valid_response(200)

      assert title == body.title
    end
  end

  describe "delete" do
    test "fails for someone who did not record it", %{
      conn: conn,
      member: member,
      recording: recording
    } do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> delete(~p"/api/recordings/#{recording.id}")
               |> valid_response(403)
    end

    test "delete recording", %{conn: conn, owner: owner, recording: recording} do
      assert conn
             |> auth_conn(owner)
             |> delete(~p"/api/recordings/#{recording.id}")
             |> response(204)

      assert %{"code" => "not_found"} =
               conn
               |> auth_conn(owner)
               |> get(~p"/api/recordings/#{recording.id}")
               |> valid_response(404)
    end
  end
end
