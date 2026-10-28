defmodule Hearth.Voice.RecordingLifecycleTest do
  use ExUnit.Case, async: true

  alias Hearth.Voice.Recording
  alias Hearth.Voice.RecordingLifecycle

  describe "next/2" do
    test "fails to finish a running recording" do
      assert {:error, :invalid_transition} =
               RecordingLifecycle.next(%Recording{status: :recording}, :finish)
    end

    test "fails to move a ready or failed recording" do
      assert {:error, :invalid_transition} =
               RecordingLifecycle.next(%Recording{status: :ready}, :fail)

      assert {:error, :invalid_transition} =
               RecordingLifecycle.next(%Recording{status: :failed}, :stop)
    end

    test "stop" do
      assert {:ok, :processing} = RecordingLifecycle.next(%Recording{status: :recording}, :stop)
    end

    test "finish" do
      assert {:ok, :ready} = RecordingLifecycle.next(%Recording{status: :processing}, :finish)
    end

    test "fail" do
      assert {:ok, :failed} = RecordingLifecycle.next(%Recording{status: :recording}, :fail)
      assert {:ok, :failed} = RecordingLifecycle.next(%Recording{status: :processing}, :fail)
    end
  end
end
