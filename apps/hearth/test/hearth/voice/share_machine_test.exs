defmodule Hearth.Voice.ShareMachineTest do
  use ExUnit.Case, async: true

  alias Hearth.Common
  alias Hearth.Voice.ShareMachine

  describe "next/2" do
    test "fails to start while held" do
      assert {:error, :invalid_transition} = ShareMachine.next(Common.new_id(), :start)
    end

    test "fails to stop while free" do
      assert {:error, :invalid_transition} = ShareMachine.next(nil, :stop)
    end

    test "takes a free slot" do
      assert {:ok, :held} = ShareMachine.next(nil, :start)
    end

    test "frees a held slot" do
      assert {:ok, :free} = ShareMachine.next(Common.new_id(), :stop)
    end
  end
end
