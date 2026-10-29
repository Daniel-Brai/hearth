defmodule HearthWeb.TranscriptControllerTest do
  use HearthWeb.ConnCase, async: true

  alias Hearth.Common
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner)
    member = TestUtils.join_random_member!(community)
    outsider = TestUtils.register_random_user!()
    session = TestUtils.insert_random_voice_session!(community)

    speakers = [{owner.id, "0 2000 Welcome"}, {member.id, "3000 5000 Thanks"}]
    transcript = TestUtils.transcribe_random_recording!(session, speakers)

    {:ok, binding()}
  end

  describe "show" do
    test "fails signed out", %{conn: conn, session: session} do
      conn
      |> get(~p"/api/voice-sessions/#{session.id}/transcript")
      |> valid_response(401)
    end

    test "fails for someone outside the community", %{
      conn: conn,
      outsider: outsider,
      session: session
    } do
      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(outsider)
               |> get(~p"/api/voice-sessions/#{session.id}/transcript")
               |> valid_response(403)
    end

    test "fails for a session without one", %{conn: conn, member: member} do
      assert %{"code" => "not_found"} =
               conn
               |> auth_conn(member)
               |> get(~p"/api/voice-sessions/#{Common.new_id()}/transcript")
               |> valid_response(404)
    end

    test "show transcript", %{conn: conn, member: member, session: session} do
      member_id = member.id

      response =
        conn
        |> auth_conn(member)
        |> get(~p"/api/voice-sessions/#{session.id}/transcript")
        |> valid_response(200)

      assert %{"status" => "ready", "segments" => [welcome, thanks], "speakers" => speakers} =
               response

      assert %{"text" => "Welcome", "editable" => false} = welcome
      assert %{"text" => "Thanks", "editable" => true} = thanks
      assert [_owner, _member] = response["people"]
      assert member_id in TestUtils.pluck(speakers, "user_id")
    end
  end

  describe "update_segment" do
    test "fails without text", %{conn: conn, member: member, transcript: transcript} do
      [_welcome, thanks] = transcript.segments

      errors =
        conn
        |> auth_conn(member)
        |> put(~p"/api/transcript-segments/#{thanks.id}", %{})
        |> valid_response(422)
        |> Map.fetch!("errors")

      assert ["The text field is required."] = errors["text"]
    end

    test "fails for a line someone else said", %{
      conn: conn,
      member: member,
      transcript: transcript
    } do
      [welcome, _thanks] = transcript.segments

      assert %{"code" => "forbidden"} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/transcript-segments/#{welcome.id}", %{text: "Hi"})
               |> valid_response(403)
    end

    test "fix own line", %{conn: conn, member: member, transcript: transcript} do
      [_welcome, thanks] = transcript.segments

      assert %{"text" => "Thank you", "edited" => true, "editable" => true} =
               conn
               |> auth_conn(member)
               |> put(~p"/api/transcript-segments/#{thanks.id}", %{text: "Thank you"})
               |> valid_response(200)
    end
  end
end
