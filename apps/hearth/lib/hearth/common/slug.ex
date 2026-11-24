defmodule Hearth.Common.Slug do
  alias Hearth.Common.Id
  alias Hearth.Common.T

  @max_length 60
  @id_length 36

  @spelled %{
    "ß" => "ss",
    "æ" => "ae",
    "œ" => "oe",
    "ø" => "o",
    "đ" => "d",
    "ð" => "d",
    "ł" => "l",
    "þ" => "th",
    "ı" => "i"
  }

  @doc """
  A slug of up to 60 lowercase Latin letters and digits joined by dashes
  Other scripts give an empty slug and links then use the id alone

      iex> Hearth.Common.Slug.slugify("Café Crème: Straße & Œuvre!")
      "cafe-creme-strasse-oeuvre"
  """
  @spec slugify(String.t()) :: T.slug()
  def slugify(text) when is_binary(text) do
    {slug, _dash?} =
      text
      |> String.downcase()
      |> :unicode.characters_to_nfkd_binary()
      |> String.codepoints()
      |> Enum.reduce_while({"", false}, &add_char/2)

    slug
    |> String.slice(0, @max_length)
    |> String.trim_trailing("-")
  end

  @spec id_slug(T.id(), nil | String.t()) :: String.t()
  def id_slug(id, nil), do: id

  def id_slug(id, title) when is_binary(title) do
    case slugify(title) do
      "" -> id
      slug -> id <> "-" <> slug
    end
  end

  # The slug is ignored so links keep working after a title change
  @spec id_from_segment(String.t()) :: {:ok, T.id()} | :error
  def id_from_segment(<<id::binary-size(@id_length)>>), do: checked(id)
  def id_from_segment(<<id::binary-size(@id_length), "-", _slug::binary>>), do: checked(id)
  def id_from_segment(_segment), do: :error

  defp checked(id) do
    case Id.valid?(id) do
      true -> {:ok, String.downcase(id)}
      false -> :error
    end
  end

  defp add_char(char, {slug, dash?}) do
    case letters(char) do
      :accent -> {:cont, {slug, dash?}}
      :separator -> {:cont, {slug, slug != ""}}
      letters -> append(slug, dash?, letters)
    end
  end

  defp append(slug, dash?, letters) do
    longer = if dash?, do: slug <> "-" <> letters, else: slug <> letters

    if String.length(longer) >= @max_length,
      do: {:halt, {longer, false}},
      else: {:cont, {longer, false}}
  end

  defp letters(<<codepoint::utf8>>) when codepoint in 0x300..0x36F, do: :accent
  defp letters(<<char>> = letter) when char in ?a..?z or char in ?0..?9, do: letter
  defp letters(char), do: Map.get(@spelled, char, :separator)
end
