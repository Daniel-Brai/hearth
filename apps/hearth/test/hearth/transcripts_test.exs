defmodule Hearth.TranscriptsTest do
  use Hearth.DataCase, async: true

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.TestUtils
  alias Hearth.Transcripts
  alias Hearth.Transcripts.Segment
  alias Hearth.Transcripts.Transcript

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

  describe "get_for_session/2" do
    test "fails for someone outside the community", %{outsider: outsider, session: session} do
      assert {:error, :forbidden} = Transcripts.get_for_session(outsider, session.id)
    end

    test "fails in a private room they can't see", %{
      owner: owner,
      member: member,
      session: session
    } do
      {:ok, room} = Communities.get_room(id: session.room_id)
      {:ok, _room} = Communities.update_room(owner, room, %{access: :roles, role_ids: []})

      assert {:error, :not_found} = Transcripts.get_for_session(member, session.id)
    end

    test "fails for a session without one", %{member: member} do
      assert {:error, :not_found} = Transcripts.get_for_session(member, Common.new_id())
    end

    test "show transcript", %{member: member, session: session, transcript: transcript} do
      assert {:ok, %{transcript: %Transcript{} = shown}} =
               Transcripts.get_for_session(member, session.id)

      assert shown.id == transcript.id
    end
  end

  describe "for_post/2" do
    test "hides it from someone outside the community", %{
      outsider: outsider,
      owner: owner,
      community: community,
      transcript: transcript
    } do
      post = TestUtils.create_random_post!(owner, community)
      :ok = TestUtils.update_rows!(Transcript, [id: transcript.id], post_id: post.id)

      refute Transcripts.for_post(outsider, post)
      refute Transcripts.for_post(nil, post)
    end

    test "returns the discussed post's transcript", %{
      member: member,
      owner: owner,
      community: community,
      transcript: transcript
    } do
      post = TestUtils.create_random_post!(owner, community)
      :ok = TestUtils.update_rows!(Transcript, [id: transcript.id], post_id: post.id)

      assert %{transcript: %Transcript{} = shown, room_name: "Voice " <> _n} =
               Transcripts.for_post(member, post)

      assert shown.id == transcript.id
    end
  end

  describe "edit_segment/3" do
    test "fails for a line someone else said", %{member: member, transcript: transcript} do
      [welcome, _thanks] = transcript.segments

      assert {:error, :forbidden} = Transcripts.edit_segment(member, welcome.id, %{text: "Hi"})
    end

    test "fails for empty text", %{member: member, transcript: transcript} do
      [_welcome, thanks] = transcript.segments

      assert {:error, changeset} = Transcripts.edit_segment(member, thanks.id, %{text: "  "})
      assert %{text: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails for a missing line", %{member: member} do
      assert {:error, :not_found} =
               Transcripts.edit_segment(member, Common.new_id(), %{text: "Hi"})
    end

    test "fix own line", %{member: member, transcript: transcript} do
      [_welcome, thanks] = transcript.segments
      params = %{text: " Thank you "}

      assert {:ok, %Segment{text: "Thank you"} = edited} =
               Transcripts.edit_segment(member, thanks.id, params)

      assert edited.edited_by_id == member.id
    end

    test "fix anyone's line as a moderator", %{owner: owner, transcript: transcript} do
      [_welcome, thanks] = transcript.segments

      assert {:ok, %Segment{text: "Thanks all"}} =
               Transcripts.edit_segment(owner, thanks.id, %{text: "Thanks all"})
    end
  end
end
