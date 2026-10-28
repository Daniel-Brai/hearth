defmodule Hearth.Voice.StateTest do
  use ExUnit.Case, async: true

  alias Hearth.Common
  alias Hearth.TestUtils
  alias Hearth.Voice.Participant
  alias Hearth.Voice.Session
  alias Hearth.Voice.State

  setup do
    [host, speaker, listener, stranger] = TestUtils.random_ids(4)

    session = %Session{
      id: Common.new_id(),
      room_id: Common.new_id(),
      community_id: Common.new_id(),
      host_id: host,
      mode: :stage
    }

    rows = [
      %Participant{user_id: host, role: :host, self_muted: false},
      %Participant{user_id: speaker, role: :speaker, self_muted: true},
      %Participant{user_id: listener, role: :listener, self_muted: true}
    ]

    state = State.new(session, rows, 4)
    now = DateTime.utc_now()
    person = %{role: :listener, hand_raised_at: nil, self_muted: true, server_muted: false}

    {:ok, binding()}
  end

  describe "room_for?/2" do
    test "fails when full", %{state: state, stranger: stranger, person: person} do
      state = State.join(state, Common.new_id(), person)

      refute State.room_for?(state, stranger)
    end

    test "always lets someone already here back", %{
      state: state,
      listener: listener,
      person: person
    } do
      state = State.join(state, Common.new_id(), person)

      assert State.room_for?(state, listener)
    end

    test "lets someone in under the limit", %{state: state, stranger: stranger} do
      assert State.room_for?(state, stranger)
    end
  end

  describe "role_on_join/4" do
    test "makes the host host", %{state: state, host: host} do
      assert :host = State.role_on_join(state, host, false, false)
    end

    test "puts speaker on stage", %{state: state, stranger: stranger} do
      assert :speaker = State.role_on_join(state, stranger, true, true)
      assert :listener = State.role_on_join(state, stranger, false, true)
    end

    test "makes everyone else listen", %{state: state, stranger: stranger} do
      assert :listener = State.role_on_join(state, stranger, true, false)
    end
  end

  describe "raise_hand/3" do
    test "fails in Open mode", %{state: state, listener: listener, now: now} do
      state = %{state | mode: :open}

      assert {:error, :open_mode} = State.raise_hand(state, listener, now)
    end

    test "fails on stage", %{state: state, speaker: speaker, now: now} do
      assert {:error, :on_stage} = State.raise_hand(state, speaker, now)
    end

    test "fails for someone not here", %{state: state, stranger: stranger, now: now} do
      assert {:error, :not_here} = State.raise_hand(state, stranger, now)
    end

    test "keeps the first time a hand went up", %{state: state, listener: listener, now: now} do
      {:ok, state} = State.raise_hand(state, listener, now)

      assert {:ok, %{people: %{^listener => %{hand_raised_at: ^now}}}} =
               State.raise_hand(state, listener, DateTime.add(now, 1, :minute))
    end
  end

  describe "hands/1" do
    test "lists the longest waiting first", %{
      state: state,
      listener: listener,
      now: now,
      person: person
    } do
      other = Common.new_id()
      joined = State.join(state, other, person)
      {:ok, raised} = State.raise_hand(joined, listener, now)
      {:ok, both} = State.raise_hand(raised, other, DateTime.add(now, -1, :minute))

      assert [^other, ^listener] = State.hands(both)
    end
  end

  describe "invite/2" do
    test "fails for a speaker", %{state: state, speaker: speaker} do
      assert {:error, :invalid_transition} = State.invite(state, speaker)
    end

    test "invites a listener and lowers their hand", %{
      state: state,
      listener: listener,
      now: now
    } do
      {:ok, state} = State.raise_hand(state, listener, now)

      assert {:ok, %{people: %{^listener => %{role: :speaker, hand_raised_at: nil}}}} =
               State.invite(state, listener)
    end
  end

  describe "demote/2" do
    test "fails for the host", %{state: state, host: host} do
      assert {:error, :invalid_transition} = State.demote(state, host)
    end

    test "mutes the speaker and ends their share", %{state: state, speaker: speaker} do
      {:ok, talking} = State.self_mute(state, speaker, false)
      {:ok, sharing} = State.start_share(talking, speaker)

      assert {:ok, %{share: nil, people: %{^speaker => %{role: :listener, self_muted: true}}}} =
               State.demote(sharing, speaker)
    end
  end

  describe "start_share/2" do
    test "fails off stage", %{state: state, listener: listener} do
      assert {:error, :not_on_stage} = State.start_share(state, listener)
    end

    test "fails while someone else shares", %{state: state, host: host, speaker: speaker} do
      {:ok, state} = State.start_share(state, host)

      assert {:error, :share_taken} = State.start_share(state, speaker)
    end

    test "takes the slot", %{state: state, speaker: speaker} do
      assert {:ok, %{share: ^speaker}} = State.start_share(state, speaker)
    end
  end

  describe "stop_share/1" do
    test "fails when nobody shares", %{state: state} do
      assert {:error, :not_sharing} = State.stop_share(state)
    end

    test "frees the slot", %{state: state, speaker: speaker} do
      {:ok, state} = State.start_share(state, speaker)

      assert {:ok, %{share: nil}} = State.stop_share(state)
    end
  end

  describe "leave/2" do
    test "ends the share of who left", %{state: state, speaker: speaker} do
      {:ok, state} = State.start_share(state, speaker)

      assert %{share: nil} = state = State.leave(state, speaker)
      refute State.here?(state, speaker)
    end
  end

  describe "routes/1" do
    test "gives listeners no send track", %{state: state, listener: listener} do
      assert %{^listener => %{send_audio: false, send_video: false}} = State.routes(state)
    end

    test "sends each speaker's audio to everyone else", %{
      state: state,
      host: host,
      speaker: speaker,
      listener: listener
    } do
      routes = State.routes(state)

      assert Enum.sort(routes[listener].receive) == Enum.sort([{host, :audio}, {speaker, :audio}])
      assert routes[host].receive == [{speaker, :audio}]
      assert routes[host].send_audio
    end

    test "sends the share to everyone but the sharer", %{
      state: state,
      speaker: speaker,
      listener: listener
    } do
      {:ok, state} = State.start_share(state, speaker)
      routes = State.routes(state)

      assert {speaker, :video} in routes[listener].receive
      refute {speaker, :video} in routes[speaker].receive
      assert routes[speaker].send_video
    end

    test "marks the server muted", %{state: state, speaker: speaker} do
      {:ok, state} = State.server_mute(state, speaker, true)

      assert %{^speaker => %{muted: true, send_audio: true}} = State.routes(state)
    end
  end
end
