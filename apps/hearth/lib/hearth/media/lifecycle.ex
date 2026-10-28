defmodule Hearth.Media.Lifecycle do
  use XFsm.Machine

  alias Hearth.Media.Asset
  alias Hearth.Media.FileType
  alias XFsm.Machine

  initial :uploading

  context %{input: %{media: media}}, do: %{media: media}

  state :uploading do
    always do
      target :processing
      guard :is?, %{status: :processing}
    end

    always do
      target :ready
      guard :is?, %{status: :ready}
    end

    always do
      target :held
      guard :is?, %{status: :held}
    end

    always do
      target :blocked
      guard :is?, %{status: :blocked}
    end

    always do
      target :failed
      guard :is?, %{status: :failed}
    end

    on :confirm do
      target :processing
      guard :kind?, %{kinds: [:image, :video]}
    end

    on :confirm do
      target :ready
      guard :kind?, %{kinds: [:document]}
    end

    on :fail do
      target :failed
    end
  end

  state :processing do
    on :processed do
      target :ready
    end

    on :hold do
      target :held
    end

    on :fail do
      target :failed
    end
  end

  state :held do
    on :allow do
      target :ready
    end

    on :block do
      target :blocked
    end
  end

  state :ready do
    on :block do
      target :blocked
    end
  end

  state :blocked do
  end

  state :failed do
  end

  @spec next(Asset.t(), atom()) :: {:ok, Asset.status()} | {:error, :invalid_transition}
  def next(%Asset{status: status} = media, event) when is_atom(event) do
    machine = Machine.init(__MODULE__, input: %{media: media})

    case Machine.transition(machine, %{type: event}) do
      %Machine{state: next} when next != status -> {:ok, next}
      %Machine{} -> {:error, :invalid_transition}
    end
  end

  @spec is?(XFsm.action_arg(), map()) :: boolean()
  def is?(%{context: %{media: media}}, %{status: status}), do: media.status == status

  @spec kind?(XFsm.action_arg(), map()) :: boolean()
  def kind?(%{context: %{media: media}}, %{kinds: kinds}) do
    FileType.kind(media.content_type) in kinds
  end
end
