defmodule Hearth.Voice.RoleMachineTest do
  use ExUnit.Case, async: true

  alias Hearth.Voice.RoleMachine

  describe "next/2" do
    test "fails to invite a speaker" do
      assert {:error, :invalid_transition} = RoleMachine.next(:speaker, :invite)
    end

    test "fails to demote a listener" do
      assert {:error, :invalid_transition} = RoleMachine.next(:listener, :demote)
    end

    test "fails to move the host" do
      assert {:error, :invalid_transition} = RoleMachine.next(:host, :invite)
      assert {:error, :invalid_transition} = RoleMachine.next(:host, :demote)
    end

    test "invites a listener" do
      assert {:ok, :speaker} = RoleMachine.next(:listener, :invite)
    end

    test "demotes a speaker" do
      assert {:ok, :listener} = RoleMachine.next(:speaker, :demote)
    end
  end
end
