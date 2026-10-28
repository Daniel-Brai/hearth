defmodule Hearth.Voice.ShareMachine do
  use XFsm.Machine

  alias Hearth.Common.T
  alias XFsm.Machine

  initial :start

  context %{input: %{holder: holder}}, do: %{holder: holder}

  state :start do
    always do
      target :free
      guard :free?
    end

    always do
      target :held
    end
  end

  state :free do
    on :start do
      target :held
    end
  end

  state :held do
    on :stop do
      target :free
    end
  end

  @spec next(nil | T.id(), :start | :stop) ::
          {:ok, :held | :free} | {:error, :invalid_transition}
  def next(holder, event) when is_atom(event) do
    machine = Machine.init(__MODULE__, input: %{holder: holder})
    from = if holder, do: :held, else: :free

    case Machine.transition(machine, %{type: event}) do
      %Machine{state: next} when next != from -> {:ok, next}
      %Machine{} -> {:error, :invalid_transition}
    end
  end

  @spec free?(XFsm.action_arg()) :: boolean()
  def free?(%{context: %{holder: holder}}), do: holder == nil
end
