defmodule Hearth.Voice.Slate do
  alias Image.Text
  @width 1_280
  @height 720
  @background [15, 20, 25]
  @white "#ffffff"
  @muted "#c9d1d9"

  @spec size() :: {pos_integer(), pos_integer()}
  def size, do: {@width, @height}

  @spec write(Path.t(), String.t(), String.t()) :: :ok | {:error, term()}
  def write(path, room, community) do
    with {:ok, base} <- Image.new(@width, @height, color: @background, bands: 3),
         {:ok, title} <- text(room, 64, :bold, @white),
         {:ok, subtitle} <- text(community, 32, :normal, @muted),
         {:ok, image} <- Image.compose(base, [centred(title, 300), centred(subtitle, 400)]),
         {:ok, _image} <- Image.write(image, path) do
      :ok
    end
  end

  defp centred(text, y), do: {text, x: div(@width - Image.width(text), 2), y: y}

  defp text(string, size, weight, color) do
    Text.text(string,
      font: "Inter",
      font_file: Application.app_dir(:hearth, "priv/fonts/Inter.ttf"),
      font_size: size,
      font_weight: weight,
      text_fill_color: color,
      width: @width - 160,
      align: :center
    )
  end
end
