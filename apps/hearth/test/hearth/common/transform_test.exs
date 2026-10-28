defmodule Hearth.Common.TransformTest do
  use ExUnit.Case, async: true

  alias Hearth.Common

  describe "remove_nil_fields/1" do
    test "keeps false and empty values" do
      assert Common.remove_nil_fields(%{a: false, b: "", c: []}) == %{a: false, b: "", c: []}
    end

    test "drops nested nils" do
      assert Common.remove_nil_fields(%{a: 1, b: nil, c: %{d: nil, e: 2}}) == %{a: 1, c: %{e: 2}}
    end

    test "keeps the order of a keyword list" do
      assert Common.remove_nil_fields(a: 1, b: nil, c: 3) == [a: 1, c: 3]
    end
  end
end
