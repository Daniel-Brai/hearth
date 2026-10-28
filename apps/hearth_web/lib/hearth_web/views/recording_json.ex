defmodule HearthWeb.RecordingJSON do
  alias Hearth.Voice
  alias HearthWeb.PageJSON

  @fields ~w[
    id
    session_id
    room_id
    community_id
    started_by_id
    title
    status
    failure
    started_at
    ended_at
    duration_ms
    byte_size
    width
    height
    has_screen
  ]a

  def index(%{recordings: recordings}), do: %{data: Enum.map(recordings, &data/1)}

  def page(%{page: page}),
    do: %{data: Enum.map(page.data, &data/1), meta: PageJSON.meta(page.meta)}

  def show(%{recording: recording}), do: data(recording)

  defp data(recording) do
    urls = Voice.recording_urls(recording)

    recording
    |> Map.take(@fields)
    |> Map.merge(%{
      video_url: urls.video,
      download_url: urls.download,
      poster_url: urls.poster,
      speakers: Enum.map(urls.speakers, fn {user_id, url} -> %{user_id: user_id, url: url} end)
    })
  end
end
