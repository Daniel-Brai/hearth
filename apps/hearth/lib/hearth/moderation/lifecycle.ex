defmodule Hearth.Moderation.Lifecycle do
  use XFsm.Machine

  alias Hearth.Moderation.Item
  alias XFsm.Machine

  # A routing state so :undo back to pending doesn't bounce
  # straight to the status the item was read with
  initial :start

  context %{input: %{item: item}}, do: %{item: item}

  state :start do
    always do
      target :pending
      guard :is?, %{status: :pending}
    end

    always do
      target :kept
      guard :is?, %{status: :kept}
    end

    always do
      target :removed
      guard :is?, %{status: :removed}
    end

    always do
      target :dismissed
      guard :is?, %{status: :dismissed}
    end
  end

  state :pending do
    on :keep do
      target :kept
    end

    on :remove do
      target :removed
    end

    on :dismiss do
      target :dismissed
    end
  end

  state :kept do
    on :undo do
      target :pending
    end
  end

  state :removed do
    on :undo do
      target :pending
    end
  end

  state :dismissed do
  end

  @spec next(Item.t(), atom()) :: {:ok, Item.status()} | {:error, :invalid_transition}
  def next(%Item{status: status} = item, event) when is_atom(event) do
    machine = Machine.init(__MODULE__, input: %{item: item})

    case Machine.transition(machine, %{type: event}) do
      %Machine{state: next} when next != status -> {:ok, next}
      %Machine{} -> {:error, :invalid_transition}
    end
  end

  @spec is?(XFsm.action_arg(), map()) :: boolean()
  def is?(%{context: %{item: item}}, %{status: status}), do: item.status == status
end
