defmodule Hearth.Common.SlugTest do
  use ExUnit.Case, async: true

  alias Hearth.Common.Slug

  doctest Slug

  @id "0192f7a8-3c4d-7e5f-8a9b-0c1d2e3f4a5b"

  describe "slugify/1" do
    test "returns empty if no latin letters" do
      assert Slug.slugify("こんにちは") == ""
      assert Slug.slugify("!!!") == ""
      assert Slug.slugify("") == ""
    end

    test "caps length at 60" do
      title = String.duplicate("word ", 30)
      slug = Slug.slugify(title)

      assert String.length(slug) <= 60
      refute String.ends_with?(slug, "-")
    end

    test "joins words with dashes" do
      assert Slug.slugify("  Turbo 8:  Morphing -- resets   state! ") ==
               "turbo-8-morphing-resets-state"
    end

    test "drops accents" do
      assert Slug.slugify("Ðað Łódź Þórr ıi Øre") == "dad-lodz-thorr-ii-ore"
    end
  end

  describe "id_slug/2" do
    test "returns id if no slug" do
      assert Slug.id_slug(@id, nil) == @id
      assert Slug.id_slug(@id, "こんにちは") == @id
    end

    test "joins id and slug" do
      assert Slug.id_slug(@id, "Morphing questions") == @id <> "-morphing-questions"
    end
  end

  describe "id_from_segment/1" do
    test "fails if no id" do
      assert Slug.id_from_segment("") == :error
      assert Slug.id_from_segment("p1-hello") == :error
      assert Slug.id_from_segment(@id <> "x") == :error
      assert Slug.id_from_segment("zzzzzzzz-3c4d-7e5f-8a9b-0c1d2e3f4a5b") == :error
    end

    test "reads id" do
      assert Slug.id_from_segment(@id) == {:ok, @id}
      assert Slug.id_from_segment(@id <> "-an-old-title") == {:ok, @id}
    end

    test "lowercases id" do
      assert @id |> String.upcase() |> Slug.id_from_segment() == {:ok, @id}
    end
  end
end
