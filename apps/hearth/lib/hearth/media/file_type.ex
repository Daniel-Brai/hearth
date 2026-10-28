defmodule Hearth.Media.FileType do
  @mb 1024 * 1024

  @images ~w[image/jpeg image/png image/webp image/gif image/avif]
  @videos ~w[video/mp4 video/quicktime video/webm video/x-matroska]

  @documents %{
    "application/pdf" => "PDF",
    "application/vnd.openxmlformats-officedocument.wordprocessingml.document" => "Word",
    "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" => "Excel",
    "application/vnd.openxmlformats-officedocument.presentationml.presentation" => "PowerPoint",
    "text/csv" => "CSV",
    "text/plain" => "plain text"
  }

  @spec content_types() :: [String.t()]
  def content_types, do: @images ++ @videos ++ Map.keys(@documents)

  @spec kind(String.t()) :: nil | :image | :video | :document
  def kind(type) when type in @images, do: :image
  def kind(type) when type in @videos, do: :video
  def kind(type) when is_map_key(@documents, type), do: :document
  def kind(_type), do: nil

  @spec max_bytes(String.t()) :: nil | pos_integer()
  def max_bytes(type) do
    case kind(type) do
      :image -> config(:max_image_mb) * @mb
      :video -> config(:max_video_mb) * @mb
      :document -> config(:max_file_mb) * @mb
      nil -> nil
    end
  end

  @spec multipart_above() :: pos_integer()
  def multipart_above, do: config(:multipart_above_mb) * @mb

  @spec max_video_ms() :: pos_integer()
  def max_video_ms, do: config(:max_video_minutes) * 60_000

  @spec max_attachments() :: pos_integer()
  def max_attachments, do: config(:max_attachments)

  @spec avif?() :: boolean()
  def avif?, do: config(:avif)

  @spec limits() :: %{
          content_types: [String.t()],
          max_image_bytes: pos_integer(),
          max_video_bytes: pos_integer(),
          max_video_seconds: pos_integer(),
          max_file_bytes: pos_integer(),
          max_attachments: pos_integer()
        }
  def limits do
    %{
      content_types: content_types(),
      max_image_bytes: config(:max_image_mb) * @mb,
      max_video_bytes: config(:max_video_mb) * @mb,
      max_video_seconds: config(:max_video_minutes) * 60,
      max_file_bytes: config(:max_file_mb) * @mb,
      max_attachments: max_attachments()
    }
  end

  @spec document_names() :: String.t()
  def document_names do
    names = @documents |> Map.values() |> Enum.sort()
    {rest, [last]} = Enum.split(names, -1)

    Enum.join(rest, ", ") <> " and " <> last
  end

  defp config(key), do: Application.fetch_env!(:hearth, Hearth.Media)[key]
end
