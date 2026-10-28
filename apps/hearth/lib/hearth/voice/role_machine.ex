defmodule Hearth.Voice.RoleMachine do
  use XFsm.Machine

  alias XFsm.Machine

  # A routing state so the machine starts at whatever role it was given
  initial :start

  context %{input: %{role: role}}, do: %{role: role}

  state :start do
    always do
      target :listener
      guard :is?, %{role: :listener}
    end

    always do
      target :speaker
      guard :is?, %{role: :speaker}
    end

    always do
      target :host
      guard :is?, %{role: :host}
    end
  end

  state :listener do
    on :invite do
      target :speaker
    end
  end

  state :speaker do
    on :demote do
      target :listener
    end
  end

  state :host do
  end

  @spec next(Hearth.Voice.Participant.role(), :invite | :demote) ::
          {:ok, Hearth.Voice.Participant.role()} | {:error, :invalid_transition}
  def next(role, event) when is_atom(role) and is_atom(event) do
    machine = Machine.init(__MODULE__, input: %{role: role})

    case Machine.transition(machine, %{type: event}) do
      %Machine{state: next} when next != role -> {:ok, next}
      %Machine{} -> {:error, :invalid_transition}
    end
  end

  @spec is?(XFsm.action_arg(), map()) :: boolean()
  def is?(%{context: %{role: role}}, %{role: wanted}), do: role == wanted
end
