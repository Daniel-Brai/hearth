defmodule Hearth.Common.Markdown do
  # Indented code is read as prose since indentation in posts is mostly nested lists

  alias Hearth.Common.T
  alias Hearth.Common.Text

  @doc """
  The usernames mentioned with @ in order and lowercased

      iex> Hearth.Common.Markdown.mentions("Thanks @Ada and @lin_chen, see `@nobody`")
      ["ada", "lin_chen"]
  """
  @spec mentions(T.markdown()) :: [String.t()]
  def mentions(markdown), do: names(markdown, ?@, ?.)

  @doc """
  The names referenced with # in order and lowercased
  The caller decides if they are tags or rooms

      iex> Hearth.Common.Markdown.refs("Moved to #general, tagged #turbo-8")
      ["general", "turbo-8"]
  """
  @spec refs(T.markdown()) :: [String.t()]
  def refs(markdown), do: names(markdown, ?#, ?-)

  @doc """
  The first http or https link outside code and images

      iex> Hearth.Common.Markdown.first_link("Docs: [Elixir](https://hexdocs.pm/elixir/).")
      "https://hexdocs.pm/elixir/"
  """
  @spec first_link(T.markdown()) :: nil | String.t()
  def first_link(markdown) do
    markdown
    |> lines()
    |> Enum.flat_map(&prose_texts/1)
    |> Enum.find_value(&link_in/1)
  end

  @doc """
  All readable text including code without Markdown syntax for search

      iex> Hearth.Common.Markdown.plain_text("## Fix\\n\\nUse **`data-phx-change`** on [the menu](https://x.dev)")
      "Fix Use data-phx-change on the menu"
  """
  @spec plain_text(T.markdown()) :: String.t()
  def plain_text(markdown) do
    markdown
    |> lines()
    |> Enum.map(&readable(&1, :keep_code))
    |> collapse()
  end

  @doc """
  The prose without code cut to max_length characters for email and push snippets

      iex> Hearth.Common.Markdown.excerpt("Keep the state in the DOM.\\n\\n```js\\nthis.x = 1\\n```", 60)
      "Keep the state in the DOM."
  """
  @spec excerpt(T.markdown(), pos_integer()) :: String.t()
  def excerpt(markdown, max_length) do
    readable =
      markdown
      |> lines()
      |> Enum.map(&readable(&1, :drop_code))
      |> collapse()

    Text.truncate(readable, max_length)
  end

  defp lines(markdown) do
    {lines, _open_fence} =
      markdown
      |> String.split("\n")
      |> Enum.map(&String.trim_trailing(&1, "\r"))
      |> Enum.flat_map_reduce(nil, &classify/2)

    lines
  end

  defp classify(line, nil) do
    case fence(line) do
      {char, size, _info} -> {[], {char, size}}
      nil -> {[{:prose, segments(line)}], nil}
    end
  end

  defp classify(line, {char, size} = open) do
    case fence(line) do
      {^char, closing, rest} when closing >= size -> close_or_keep(line, rest, open)
      _other -> {[{:code, line}], open}
    end
  end

  defp close_or_keep(line, rest, open) do
    case String.trim(rest) do
      "" -> {[], nil}
      _info -> {[{:code, line}], open}
    end
  end

  defp fence(line) do
    case String.trim_leading(line) do
      <<"```", _rest::binary>> = trimmed -> fence_run(trimmed, ?`)
      <<"~~~", _rest::binary>> = trimmed -> fence_run(trimmed, ?~)
      _other -> nil
    end
  end

  defp fence_run(text, char) do
    {size, rest} = count_run(text, char, 0)
    {char, size, rest}
  end

  defp count_run(<<char, rest::binary>>, char, count), do: count_run(rest, char, count + 1)
  defp count_run(rest, _char, count), do: {count, rest}

  defp segments(line), do: split_spans(line, "", [])

  defp split_spans(<<>>, text, acc) do
    acc
    |> push_text(text)
    |> Enum.reverse()
  end

  defp split_spans(<<?`, _rest::binary>> = line, text, acc) do
    {ticks, after_ticks} = count_run(line, ?`, 0)

    case close_span(after_ticks, ticks, "") do
      {:ok, code, rest} -> split_spans(rest, "", [{:code, code} | push_text(acc, text)])
      :error -> split_spans(after_ticks, text <> String.duplicate("`", ticks), acc)
    end
  end

  defp split_spans(<<byte, rest::binary>>, text, acc),
    do: split_spans(rest, text <> <<byte>>, acc)

  defp close_span(<<>>, _ticks, _code), do: :error

  defp close_span(<<?`, _rest::binary>> = text, ticks, code) do
    case count_run(text, ?`, 0) do
      {^ticks, rest} -> {:ok, String.trim(code), rest}
      {other, rest} -> close_span(rest, ticks, code <> String.duplicate("`", other))
    end
  end

  defp close_span(<<byte, rest::binary>>, ticks, code),
    do: close_span(rest, ticks, code <> <<byte>>)

  defp push_text(acc, ""), do: acc
  defp push_text(acc, text), do: [{:text, text} | acc]

  defp prose_texts({:prose, segments}), do: for({:text, text} <- segments, do: text)
  defp prose_texts({:code, _line}), do: []

  defp names(markdown, sigil, inner) do
    markdown
    |> lines()
    |> Enum.flat_map(&prose_texts/1)
    |> Enum.flat_map(&collect(&1, sigil, inner, true, []))
    |> Enum.map(&String.downcase/1)
    |> Enum.uniq()
  end

  defp collect(<<>>, _sigil, _inner, _boundary?, acc), do: Enum.reverse(acc)

  defp collect(<<sigil, rest::binary>>, sigil, inner, true, acc) do
    case take_name(rest, inner) do
      {"", remaining} -> collect(remaining, sigil, inner, false, acc)
      {name, remaining} -> collect(remaining, sigil, inner, false, [name | acc])
    end
  end

  defp collect(<<char, rest::binary>>, sigil, inner, _boundary?, acc) do
    collect(rest, sigil, inner, char in ~c" \t(", acc)
  end

  defp take_name(<<first, _rest::binary>> = text, inner)
       when first in ?a..?z or first in ?A..?Z do
    {name, rest} = take_name_chars(text, inner, "")
    {String.trim_trailing(name, <<inner>>), rest}
  end

  defp take_name(text, _inner), do: {"", text}

  defp take_name_chars(<<char, rest::binary>>, inner, name)
       when char in ?a..?z or char in ?A..?Z or char in ?0..?9 or char == ?_ or char == inner do
    take_name_chars(rest, inner, name <> <<char>>)
  end

  defp take_name_chars(rest, _inner, name), do: {name, rest}

  defp link_in(text) do
    without_images = drop_images(text)

    case :binary.match(without_images, ~w[https:// http://]) do
      {start, _length} -> url_at(without_images, start)
      :nomatch -> nil
    end
  end

  defp url_at(text, start) do
    <<_before::binary-size(^start), from::binary>> = text
    {url, _rest} = take_url(from, "")
    trim_url(url)
  end

  defp take_url(<<char, _rest::binary>> = rest, url) when char in ~c" \t<>\"`", do: {url, rest}
  defp take_url(<<char, rest::binary>>, url), do: take_url(rest, url <> <<char>>)
  defp take_url(<<>>, url), do: {url, ""}

  defp trim_url(url) do
    case String.last(url) do
      last when last in ~w[. , ; : ! ? ' "] -> trim_url(String.slice(url, 0..-2//1))
      ")" -> trim_unbalanced(url, "(", ")")
      "]" -> trim_unbalanced(url, "[", "]")
      _other -> url
    end
  end

  defp trim_unbalanced(url, open, close) do
    opened = count(url, open)
    closed = count(url, close)

    case closed > opened do
      true -> trim_url(String.slice(url, 0..-2//1))
      false -> url
    end
  end

  defp count(text, part) do
    parts = String.split(text, part)
    length(parts) - 1
  end

  defp drop_images(text) do
    case :binary.split(text, "![") do
      [before, rest] -> before <> skip_image(rest)
      [_whole] -> text
    end
  end

  defp skip_image(text) do
    with [_alt, after_alt] <- :binary.split(text, "]("),
         [_address, rest] <- :binary.split(after_alt, ")") do
      drop_images(rest)
    else
      _no_image -> "![" <> drop_images(text)
    end
  end

  defp unlink(text) do
    case :binary.split(text, "[") do
      [before, rest] -> before <> link_label(rest)
      [_whole] -> text
    end
  end

  defp link_label(text) do
    with [label, after_label] <- :binary.split(text, "]("),
         [_address, rest] <- :binary.split(after_label, ")") do
      label <> unlink(rest)
    else
      _no_link -> "[" <> unlink(text)
    end
  end

  defp readable({:code, line}, :keep_code), do: line
  defp readable({:code, _line}, :drop_code), do: ""

  defp readable({:prose, segments}, code) do
    segments
    |> Enum.map_join(" ", &readable_segment(&1, code))
    |> drop_block_marker()
  end

  defp readable_segment({:code, text}, :keep_code), do: text
  defp readable_segment({:code, _text}, :drop_code), do: ""

  defp readable_segment({:text, text}, _code) do
    text
    |> drop_images()
    |> unlink()
    |> String.replace(~w[** __ ~~ * < > |], " ")
  end

  defp drop_block_marker(line) do
    trimmed = String.trim(line)

    case rule?(trimmed) do
      true -> ""
      false -> drop_list_marker(trimmed)
    end
  end

  defp rule?(line) do
    chars = String.to_charlist(line)

    length(chars) >= 3 and Enum.all?(chars, &(&1 in ~c"-*_: ")) and
      Enum.any?(chars, &(&1 in ~c"-*_"))
  end

  defp drop_list_marker(<<marker>>) when marker in ~c"-+", do: ""
  defp drop_list_marker(<<marker, " ", rest::binary>>) when marker in ~c"-+", do: drop_task(rest)

  defp drop_list_marker(<<"#", _rest::binary>> = line) do
    case count_run(line, ?#, 0) do
      {level, <<" ", heading::binary>>} when level <= 6 -> heading
      _not_heading -> line
    end
  end

  defp drop_list_marker(line), do: drop_ordered_marker(line, "")

  defp drop_ordered_marker(<<digit, rest::binary>>, digits) when digit in ?0..?9 do
    drop_ordered_marker(rest, digits <> <<digit>>)
  end

  defp drop_ordered_marker(<<marker>>, digits) when marker in ~c".)" and digits != "", do: ""

  defp drop_ordered_marker(<<marker, " ", rest::binary>>, digits)
       when marker in ~c".)" and digits != "",
       do: drop_task(rest)

  defp drop_ordered_marker(rest, digits), do: digits <> rest

  defp drop_task(<<"[", mark, "] ", rest::binary>>) when mark in ~c" xX", do: rest
  defp drop_task(rest), do: rest

  defp collapse(parts) do
    parts
    |> Enum.join(" ")
    |> String.split()
    |> Enum.join(" ")
  end
end
