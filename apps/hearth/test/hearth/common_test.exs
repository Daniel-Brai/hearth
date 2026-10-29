defmodule Hearth.CommonTest do
  use ExUnit.Case, async: true

  alias Hearth.Common

  defmodule Announced do
    @behaviour GenServer

    defstruct [:id]

    @impl GenServer
    def init(state), do: {:ok, state}
  end

  describe "implements?/2" do
    test "fails if behaviour not declared" do
      refute Common.implements?(%Announced{}, Supervisor)
      refute Common.implements?(%{}, GenServer)
      refute Common.implements?("text", GenServer)
    end

    test "implements behaviour" do
      assert Common.implements?(%Announced{}, GenServer)
    end
  end

  describe "valid_id?/1" do
    test "fails if not a uuid" do
      refute Common.valid_id?("p1")
      refute Common.valid_id?("")
      refute Common.valid_id?(nil)
      refute Common.valid_id?(42)
    end

    test "accepts new id" do
      assert Common.valid_id?(Common.new_id())
    end
  end

  describe "new_id/0" do
    test "sorts by creation time" do
      older = Common.new_id()
      newer = Common.new_id()

      assert String.at(older, 14) == "7"
      assert older < newer
    end
  end
end
