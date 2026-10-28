defmodule Hearth.Voice.RecordingLifecycle do
  use XFsm.Machine

  alias Hearth.Voice.Recording
  alias XFsm.Machine

  initial :start

  context %{input: %{recording: recording}}, do: %{recording: recording}

  state :start do
    always do
      target :recording
      guard :is?, %{status: :recording}
    end

    always do
      target :processing
      guard :is?, %{status: :processing}
    end

    always do
      target :ready
      guard :is?, %{status: :ready}
    end

    always do
      target :failed
      guard :is?, %{status: :failed}
    end
  end

  state :recording do
    on :stop do
      target :processing
    end

    on :fail do
      target :failed
    end
  end

  state :processing do
    on :finish do
      target :ready
    end

    on :fail do
      target :failed
    end
  end

  state :ready do
  end

  state :failed do
  end

  @spec next(Recording.t(), atom()) ::
          {:ok, Recording.status()} | {:error, :invalid_transition}
  def next(%Recording{status: status} = recording, event) when is_atom(event) do
    machine = Machine.init(__MODULE__, input: %{recording: recording})

    case Machine.transition(machine, %{type: event}) do
      %Machine{state: next} when next != status -> {:ok, next}
      %Machine{} -> {:error, :invalid_transition}
    end
  end

  @spec is?(XFsm.action_arg(), map()) :: boolean()
  def is?(%{context: %{recording: recording}}, %{status: status}),
    do: recording.status == status
end
