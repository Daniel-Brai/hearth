defmodule Hearth.Transcripts.TranscriptLifecycle do
  use XFsm.Machine

  alias Hearth.Transcripts.Transcript
  alias XFsm.Machine

  initial :start

  context %{input: %{transcript: transcript}}, do: %{transcript: transcript}

  state :start do
    always do
      target :queued
      guard :is?, %{status: :queued}
    end

    always do
      target :transcribing
      guard :is?, %{status: :transcribing}
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

  state :queued do
    on :start do
      target :transcribing
    end

    on :fail do
      target :failed
    end
  end

  state :transcribing do
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

  @spec next(Transcript.t(), atom()) ::
          {:ok, Transcript.status()} | {:error, :invalid_transition}
  def next(%Transcript{status: status} = transcript, event) when is_atom(event) do
    machine = Machine.init(__MODULE__, input: %{transcript: transcript})

    case Machine.transition(machine, %{type: event}) do
      %Machine{state: next} when next != status -> {:ok, next}
      %Machine{} -> {:error, :invalid_transition}
    end
  end

  @spec is?(XFsm.action_arg(), map()) :: boolean()
  def is?(%{context: %{transcript: transcript}}, %{status: status}),
    do: transcript.status == status
end
