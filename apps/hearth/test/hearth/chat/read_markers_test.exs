defmodule Hearth.Chat.ReadMarkersTest do
  use ExUnit.Case, async: true

  alias Hearth.Chat.ReadMarkers
  alias Hearth.Common
  alias Hearth.TestUtils

  describe "version/1" do
    test "orders ids by when they were made" do
      older = Common.new_id()
      newer = Common.new_id()

      assert ReadMarkers.version(older) < ReadMarkers.version(newer)
    end

    # Tests write through, so this runs the buffer the server runs
    test "keeps the newer mark in the buffer" do
      name = __MODULE__.Buffer
      older = Common.new_id()
      newer = Common.new_id()

      TestUtils.start_flushing_buffer!(name)

      :ok = PartitionedBuffer.Map.put_newer(name, :key, newer, ReadMarkers.version(newer))
      :ok = PartitionedBuffer.Map.put_newer(name, :key, older, ReadMarkers.version(older))

      assert_receive {:flushed, [{:key, ^newer, _version, _updates}]}
    end
  end
end
