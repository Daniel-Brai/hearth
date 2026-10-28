defmodule Hearth.Voice.Command.EndSessionTest do
  use Hearth.DataCase, async: true

  alias Hearth.TestUtils
  alias Hearth.Voice.Command.EndSession
  alias Hearth.Voice.Participant
  alias Hearth.Voice.Session

  setup do
    community = TestUtils.create_random_community!()
    member = TestUtils.join_random_member!(community)
    session = TestUtils.insert_random_voice_session!(community)
    {:ok, _participant} = Participant.enter(session.id, member.id, :listener)

    {:ok, binding()}
  end

  describe "execute/1" do
    test "ends once", %{session: session} do
      {:ok, %Session{ended_at: ended_at}} = EndSession.execute(session)

      ended = Session.get(id: session.id)

      assert {:ok, %Session{ended_at: ^ended_at}} = EndSession.execute(ended)
    end

    test "end session", %{session: session} do
      assert {:ok, %Session{ended_at: %DateTime{}}} = EndSession.execute(session)
      assert [] = Participant.present(session.id)
      assert nil == Session.live_in(session.room_id)
    end
  end
end
