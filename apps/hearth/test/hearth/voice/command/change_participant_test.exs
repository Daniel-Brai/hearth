defmodule Hearth.Voice.Command.ChangeParticipantTest do
  use Hearth.DataCase, async: true

  alias Hearth.Moderation.Action
  alias Hearth.TestUtils
  alias Hearth.Voice.Command.ChangeParticipant
  alias Hearth.Voice.Participant

  setup do
    community = TestUtils.create_random_community!()
    member = TestUtils.join_random_member!(community)
    session = TestUtils.insert_random_voice_session!(community)
    {:ok, participant} = Participant.enter(session.id, member.id, :speaker)
    log = %{actor_id: community.owner_id, action: :server_muted, session: session}

    {:ok, binding()}
  end

  describe "execute/3" do
    test "fails for a role it doesn't know", %{participant: participant} do
      assert_raise Ecto.ChangeError, fn ->
        ChangeParticipant.execute(participant, %{role: :guest}, nil)
      end
    end

    test "saves a change without a log", %{participant: participant, member: member} do
      assert {:ok, %Participant{self_muted: false}} =
               ChangeParticipant.execute(participant, %{self_muted: false}, nil)

      refute Action.exists?(target_id: member.id)
    end

    test "logs a host action", %{participant: participant, member: member, log: log} do
      at = DateTime.utc_now()

      assert {:ok, %Participant{server_muted_at: ^at}} =
               ChangeParticipant.execute(participant, %{server_muted_at: at}, log)

      assert Action.exists?(target_id: member.id, action: :server_muted, subject_type: :room)
    end

    test "writes the change and its log together", %{
      participant: participant,
      member: member,
      log: log
    } do
      :ok =
        TestUtils.roll_back!(fn ->
          ChangeParticipant.execute(participant, %{server_muted_at: DateTime.utc_now()}, log)
        end)

      refute Action.exists?(target_id: member.id)
      assert %Participant{server_muted_at: nil} = Participant.get(id: participant.id)
    end
  end
end
