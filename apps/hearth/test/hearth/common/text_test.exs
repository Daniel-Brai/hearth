defmodule Hearth.Common.TextTest do
  use ExUnit.Case, async: true

  alias Hearth.Common.Text

  doctest Text

  describe "valid_username?/1" do
    test "fails for invalid username" do
      refute Text.valid_username?("ab")
      refute "a" |> String.duplicate(21) |> Text.valid_username?()
      refute Text.valid_username?("Ada")
      refute Text.valid_username?("ada.park")
      refute Text.valid_username?("ada park")
      refute Text.valid_username?(nil)
    end

    test "accepts valid username" do
      assert Text.valid_username?("ada")
      assert Text.valid_username?("lin_chen_2026")
    end
  end

  describe "normalize/1" do
    test "trims and lowercases" do
      assert Text.normalize("  Ada_Park ") == "ada_park"
      assert Text.normalize(" Ada@Example.COM\n") == "ada@example.com"
    end
  end

  describe "truncate/2" do
    test "cuts word if no space near" do
      assert Text.truncate("Supercalifragilistic", 8) == "Superca…"
    end

    test "counts characters not bytes" do
      assert Text.truncate("Ẹ kú àárọ̀ o, ẹ ṣé", 9) == "Ẹ kú…"
    end

    test "keeps short text" do
      assert Text.truncate("Short", 10) == "Short"
    end
  end
end
