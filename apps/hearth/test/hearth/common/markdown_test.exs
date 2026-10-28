defmodule Hearth.Common.MarkdownTest do
  use ExUnit.Case, async: true

  alias Hearth.Common.Markdown

  doctest Markdown

  describe "mentions/1" do
    test "ignores emails and code" do
      text = """
      Mail ada@example.com or ping @marco.

      ```elixir
      # @ignored in a fence
      ```

      Inline ``@also_ignored`` too.
      """

      assert Markdown.mentions(text) == ["marco"]
    end

    test "returns empty if none" do
      assert Markdown.mentions("") == []
      assert Markdown.mentions("@ alone and @1st") == []
    end

    test "allows dots in handle" do
      assert Markdown.mentions("Thanks @ada.park.") == ["ada.park"]
    end

    test "finds each mention once" do
      assert Markdown.mentions("@ada said (@lin agreed) @Ada") == ~w[ada lin]
    end
  end

  describe "refs/1" do
    test "ignores headings links and code" do
      text = "# Release notes\n\nhttps://hexdocs.pm/ecto/Ecto.html#summary `#nope`"

      assert Markdown.refs(text) == []
    end

    test "treats unclosed fence as code" do
      assert Markdown.refs("#before\n```\n#never") == ["before"]
    end

    test "reads after fence closes" do
      assert Markdown.refs("~~~\n#nope\n~~~\n#yes") == ["yes"]
      assert Markdown.refs("```\r\n#nope\r\n```\r\n#yes") == ["yes"]
    end

    test "allows dashes in name" do
      assert Markdown.refs("See #turbo-8- and #help") == ~w[turbo-8 help]
    end
  end

  describe "first_link/1" do
    test "returns nil if no link" do
      assert Markdown.first_link("") == nil
      assert Markdown.first_link("No links here, just ftp://old.server") == nil
      assert Markdown.first_link("![only an image](https://cdn.example/a.png)") == nil
    end

    test "skips images and code" do
      text =
        "![logo](https://cdn.example/logo.png) `https://not.this` then https://hearth.dev/docs"

      assert Markdown.first_link(text) == "https://hearth.dev/docs"
    end

    test "keeps brackets in address" do
      assert Markdown.first_link("(https://en.wikipedia.org/wiki/Turbo_(software))") ==
               "https://en.wikipedia.org/wiki/Turbo_(software)"
    end

    test "reads autolink" do
      assert Markdown.first_link("<https://hearth.dev>") == "https://hearth.dev"
    end
  end

  describe "plain_text/1" do
    test "returns empty if only markup" do
      assert Markdown.plain_text("---\n\n> \n- \n1.") == ""
    end

    test "drops block markers" do
      text = """
      > Quote with **bold**
      - [x] done
      2. second
      ---
      | a | b |
      |---|:-:|
      """

      assert Markdown.plain_text(text) == "Quote with bold done second a b"
    end

    test "keeps code text" do
      assert Markdown.plain_text("Run\n```sh\nmix test\n```") == "Run mix test"
    end

    test "keeps underscores in words" do
      assert Markdown.plain_text("set data_turbo_permanent") == "set data_turbo_permanent"
    end
  end

  describe "excerpt/2" do
    test "returns empty if only code and images" do
      assert Markdown.excerpt("![shot](attachment:f1)\n```\ncode\n```", 40) == ""
    end

    test "skips code and images" do
      text =
        "![shot](attachment:f1) Keep the state in the DOM, not on the instance `x = 1` please"

      assert Markdown.excerpt(text, 32) == "Keep the state in the DOM, not…"
    end
  end
end
