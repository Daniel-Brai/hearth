defmodule Hearth.Voice.State do
  alias Hearth.Common.T
  alias Hearth.Voice.Participant
  alias Hearth.Voice.RoleMachine
  alias Hearth.Voice.ShareMachine

  @enforce_keys ~w[session_id room_id community_id host_id mode limit]a
  defstruct [
    :session_id,
    :room_id,
    :community_id,
    :host_id,
    :mode,
    :limit,
    people: %{},
    share: nil
  ]

  @type person :: %{
          role: Participant.role(),
          hand_raised_at: nil | DateTime.t(),
          self_muted: boolean(),
          server_muted: boolean()
        }

  @type t :: %__MODULE__{
          session_id: T.id(),
          room_id: T.id(),
          community_id: T.id(),
          host_id: nil | T.id(),
          mode: :stage | :open,
          limit: pos_integer(),
          people: %{T.id() => person()},
          share: nil | T.id()
        }

  @type route :: %{
          send_audio: boolean(),
          send_video: boolean(),
          muted: boolean(),
          receive: [{T.id(), :audio | :video}]
        }

  @spec new(Hearth.Voice.Session.t(), [Participant.t()], pos_integer()) :: t()
  def new(session, participants, limit) do
    %__MODULE__{
      session_id: session.id,
      room_id: session.room_id,
      community_id: session.community_id,
      host_id: session.host_id,
      mode: session.mode,
      limit: limit,
      people: Map.new(participants, &{&1.user_id, person(&1)})
    }
  end

  @spec person(Participant.t()) :: person()
  def person(%Participant{} = p) do
    %{
      role: p.role,
      hand_raised_at: p.hand_raised_at,
      self_muted: p.self_muted,
      server_muted: p.server_muted_at != nil
    }
  end

  @spec here?(t(), T.id()) :: boolean()
  def here?(%__MODULE__{people: people}, user_id), do: Map.has_key?(people, user_id)

  # Someone already here always may so a rejoin after a dropped connection never hits the limit
  @spec room_for?(t(), T.id()) :: boolean()
  def room_for?(%__MODULE__{} = state, user_id) do
    here?(state, user_id) or map_size(state.people) < state.limit
  end

  @spec role_on_join(t(), T.id(), boolean(), boolean()) :: Participant.role()
  def role_on_join(%__MODULE__{host_id: host}, host, _wants_stage?, _may_speak?), do: :host
  def role_on_join(%__MODULE__{}, _user_id, true, true), do: :speaker
  def role_on_join(%__MODULE__{}, _user_id, _wants_stage?, _may_speak?), do: :listener

  @spec join(t(), T.id(), person()) :: t()
  def join(%__MODULE__{} = state, user_id, person) do
    %{state | people: Map.put(state.people, user_id, person)}
  end

  @spec leave(t(), T.id()) :: t()
  def leave(%__MODULE__{} = state, user_id) do
    share = if state.share == user_id, do: nil, else: state.share
    %{state | people: Map.delete(state.people, user_id), share: share}
  end

  @spec may_speak?(t(), T.id()) :: boolean()
  def may_speak?(%__MODULE__{people: people, mode: mode}, user_id) do
    case people do
      %{^user_id => %{role: role}} -> mode == :open or role in [:host, :speaker]
      %{} -> false
    end
  end

  @spec raise_hand(t(), T.id(), DateTime.t()) :: {:ok, t()} | {:error, atom()}
  def raise_hand(%__MODULE__{mode: :open}, _user_id, _at), do: {:error, :open_mode}

  def raise_hand(%__MODULE__{} = state, user_id, at) do
    case fetch(state, user_id) do
      {:ok, %{role: :listener} = person} ->
        {:ok, put(state, user_id, %{person | hand_raised_at: person.hand_raised_at || at})}

      {:ok, _person} ->
        {:error, :on_stage}

      error ->
        error
    end
  end

  @spec lower_hand(t(), T.id()) :: {:ok, t()} | {:error, :not_here}
  def lower_hand(%__MODULE__{} = state, user_id) do
    with {:ok, person} <- fetch(state, user_id) do
      {:ok, put(state, user_id, %{person | hand_raised_at: nil})}
    end
  end

  @spec hands(t()) :: [T.id()]
  def hands(%__MODULE__{people: people}) do
    people
    |> Enum.filter(fn {_id, p} -> p.hand_raised_at end)
    |> Enum.sort_by(fn {_id, p} -> DateTime.to_unix(p.hand_raised_at, :microsecond) end)
    |> Enum.map(fn {id, _p} -> id end)
  end

  @spec invite(t(), T.id()) :: {:ok, t()} | {:error, atom()}
  def invite(%__MODULE__{} = state, user_id) do
    with {:ok, person} <- fetch(state, user_id),
         {:ok, role} <- RoleMachine.next(person.role, :invite) do
      {:ok, put(state, user_id, %{person | role: role, hand_raised_at: nil})}
    end
  end

  # In Stage mode their share ends since only people on stage share
  @spec demote(t(), T.id()) :: {:ok, t()} | {:error, atom()}
  def demote(%__MODULE__{} = state, user_id) do
    with {:ok, person} <- fetch(state, user_id),
         {:ok, role} <- RoleMachine.next(person.role, :demote) do
      state = put(state, user_id, %{person | role: role, self_muted: true})
      {:ok, drop_share_without_voice(state)}
    end
  end

  @spec server_mute(t(), T.id(), boolean()) :: {:ok, t()} | {:error, atom()}
  def server_mute(%__MODULE__{} = state, user_id, muted?) when is_boolean(muted?) do
    with {:ok, person} <- fetch(state, user_id) do
      {:ok, put(state, user_id, %{person | server_muted: muted?})}
    end
  end

  @spec self_mute(t(), T.id(), boolean()) :: {:ok, t()} | {:error, atom()}
  def self_mute(%__MODULE__{} = state, user_id, muted?) when is_boolean(muted?) do
    with {:ok, person} <- fetch(state, user_id) do
      {:ok, put(state, user_id, %{person | self_muted: muted?})}
    end
  end

  @spec start_share(t(), T.id()) :: {:ok, t()} | {:error, atom()}
  def start_share(%__MODULE__{share: user_id} = state, user_id), do: {:ok, state}

  def start_share(%__MODULE__{} = state, user_id) do
    with true <- may_speak?(state, user_id),
         {:ok, :held} <- share_next(state.share, :start) do
      {:ok, %{state | share: user_id}}
    else
      false -> {:error, :not_on_stage}
      error -> error
    end
  end

  @spec stop_share(t()) :: {:ok, t()} | {:error, :not_sharing}
  def stop_share(%__MODULE__{} = state) do
    case ShareMachine.next(state.share, :stop) do
      {:ok, :free} -> {:ok, %{state | share: nil}}
      {:error, :invalid_transition} -> {:error, :not_sharing}
    end
  end

  # Someone server muted still receives, but what they send is dropped
  @spec routes(t()) :: %{T.id() => route()}
  def routes(%__MODULE__{people: people} = state) do
    speakers = for {id, _p} <- people, may_speak?(state, id), do: id

    Map.new(people, fn {id, person} ->
      audio = for other <- speakers, other != id, do: {other, :audio}
      video = if state.share in [nil, id], do: [], else: [{state.share, :video}]

      {id,
       %{
         send_audio: id in speakers,
         send_video: state.share == id,
         muted: person.server_muted,
         receive: audio ++ video
       }}
    end)
  end

  @spec fetch(t(), T.id()) :: {:ok, person()} | {:error, :not_here}
  def fetch(%__MODULE__{people: people}, user_id) do
    case people do
      %{^user_id => person} -> {:ok, person}
      %{} -> {:error, :not_here}
    end
  end

  defp put(state, user_id, person), do: %{state | people: Map.put(state.people, user_id, person)}

  defp share_next(holder, event) do
    case ShareMachine.next(holder, event) do
      {:error, :invalid_transition} -> {:error, :share_taken}
      ok -> ok
    end
  end

  defp drop_share_without_voice(%__MODULE__{share: nil} = state), do: state

  defp drop_share_without_voice(%__MODULE__{share: holder} = state) do
    if may_speak?(state, holder), do: state, else: %{state | share: nil}
  end
end
