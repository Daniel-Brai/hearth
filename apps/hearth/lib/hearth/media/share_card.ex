defmodule Hearth.Media.ShareCard do
  alias Hearth.Media.Asset
  alias Image.Text

  @width 1200
  @height 630
  @margin 72
  @title_chars 110

  # The mark is built into this module so a release needs no copy
  @mark_path Path.expand("../../../../../web/public/icon-192.png", __DIR__)
  @external_resource @mark_path
  @mark File.read!(@mark_path)

  @background [15, 20, 25]
  @white "#ffffff"
  @muted "#c9d1d9"
  @accent "#f08a24"

  defstruct [
    :title,
    :eyebrow,
    :heading,
    :subheading,
    :footer,
    :logo,
    :banner,
    brand: "Hearth"
  ]

  @type t :: %__MODULE__{
          title: String.t(),
          eyebrow: nil | String.t(),
          heading: nil | String.t(),
          subheading: nil | String.t(),
          footer: nil | String.t(),
          logo: nil | Asset.t(),
          banner: nil | Asset.t(),
          brand: String.t()
        }

  @spec fingerprint(t()) :: String.t()
  def fingerprint(%__MODULE__{} = card) do
    parts = [
      :v1,
      card.title,
      card.eyebrow,
      card.heading,
      card.subheading,
      card.footer,
      card.brand,
      get_in(card.logo.id),
      get_in(card.banner.id)
    ]

    :sha256
    |> :crypto.hash(:erlang.term_to_binary(parts))
    |> Base.encode16(case: :lower)
  end

  @spec draw(t(), (Asset.t() -> nil | Vix.Vips.Image.t())) :: {:ok, binary()} | {:error, term()}
  def draw(%__MODULE__{} = card, open) when is_function(open, 1) do
    with {:ok, base} <- background(open_image(card.banner, open)),
         {:ok, layers} <- layers(card, open_image(card.logo, open)),
         {:ok, image} <- Image.compose(base, layers) do
      Image.write(image, :memory, suffix: ".jpg", quality: 85)
    end
  end

  defp background(nil), do: Image.new(@width, @height, color: @background, bands: 3)

  defp background(banner) do
    with {:ok, banner} <- Image.thumbnail(banner, @width, height: @height, crop: :center),
         {:ok, banner} <- Image.flatten(banner),
         {:ok, shade} <- Image.new(@width, @height, color: @background, bands: 3),
         {:ok, shade} <- Image.add_alpha(shade, 200) do
      Image.compose(banner, shade)
    end
  end

  defp layers(card, logo) do
    with {:ok, mark} <- Image.from_binary(@mark),
         {:ok, mark} <- Image.thumbnail(mark, 40),
         {:ok, logo_layer} <- logo_layer(logo) do
      text_x = if logo_layer == [], do: @margin, else: @margin + 108
      eyebrow = if card.eyebrow, do: String.upcase(card.eyebrow)

      layers =
        logo_layer ++
          text(card.heading, 34, :bold, @white, [], x: text_x, y: 74) ++
          text(card.subheading, 24, :normal, @muted, [], x: text_x, y: 118) ++
          text(eyebrow, 24, :bold, @accent, [],
            x: @margin,
            y: 222
          ) ++
          text(shorten(card.title), 64, :ultrabold, @white, [width: @width - 2 * @margin],
            x: @margin,
            y: 262
          ) ++
          text(card.footer, 26, :normal, @muted, [width: 860], x: @margin, y: 548) ++
          [{mark, x: @width - 188, y: 540}] ++
          text(card.brand, 28, :bold, @white, [], x: @width - 138, y: 546)

      {:ok, layers}
    end
  end

  defp logo_layer(nil), do: {:ok, []}

  defp logo_layer(logo) do
    with {:ok, logo} <- Image.thumbnail(logo, 88, height: 88, crop: :center),
         {:ok, logo} <- Image.avatar(logo, size: 88) do
      {:ok, [{logo, x: @margin, y: 64}]}
    end
  end

  defp text(nil, _size, _weight, _color, _options, _at), do: []
  defp text("", _size, _weight, _color, _options, _at), do: []

  defp text(string, size, weight, color, options, at) do
    {:ok, image} =
      Text.text(
        string,
        [
          font: "Inter",
          font_file: font_path(),
          font_size: size,
          font_weight: weight,
          text_fill_color: color
        ] ++ options
      )

    [{image, at}]
  end

  # Three lines of large type hold about this many characters
  defp shorten(title) when byte_size(title) <= @title_chars, do: title

  defp shorten(title) do
    title
    |> String.slice(0, @title_chars)
    |> String.replace(~r/\s+\S*$/u, "")
    |> Kernel.<>("…")
  end

  defp font_path, do: Application.app_dir(:hearth, "priv/fonts/Inter.ttf")

  defp open_image(nil, _open), do: nil
  defp open_image(asset, open), do: open.(asset)
end
