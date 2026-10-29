defmodule Hearth.Media.Worker.ProcessVideoTest do
  use Hearth.DataCase, async: true

  alias Hearth.Media
  alias Hearth.Media.Asset
  alias Hearth.Media.MediaFailed
  alias Hearth.Media.MediaReady
  alias Hearth.Media.Video
  alias Hearth.Media.Worker.ProcessVideo
  alias Hearth.Storage
  alias Hearth.TestUtils

  setup do
    :ok = Media.subscribe_to_pubsub()

    {:ok, user: TestUtils.register_random_user!()}
  end

  describe "perform/1" do
    test "cancels when the original is gone", %{user: user} do
      media = TestUtils.upload_random_file!(user, :video)
      :ok = Storage.delete(media.bucket_key)

      assert {:cancel, :missing} = perform_job(ProcessVideo, %{media_id: media.id})
      assert_receive %MediaFailed{media_id: id} when id == media.id
    end

    test "cancels a file that isn't a video", %{user: user} do
      media = TestUtils.upload_random_file!(user, content_type: "video/mp4")

      assert {:cancel, :unreadable} = perform_job(ProcessVideo, %{media_id: media.id})
    end

    test "cancels a video longer than the limit", %{user: user} do
      opts = [size: "16x16", seconds: 21 * 60, audio: false]
      media = TestUtils.upload_random_file!(user, :video, opts)

      assert {:cancel, :too_long} = perform_job(ProcessVideo, %{media_id: media.id})
    end

    test "cancels a video bigger than 4K", %{user: user} do
      media = TestUtils.upload_random_file!(user, :video, size: "4000x2000", seconds: 1)

      assert {:cancel, :too_big} = perform_job(ProcessVideo, %{media_id: media.id})
    end

    test "does nothing once the row has moved on", %{user: user} do
      media = TestUtils.upload_random_file!(user, :video)
      {:ok, _media} = Asset.advance(media, :hold)

      assert :ok = perform_job(ProcessVideo, %{media_id: media.id})
      assert %Asset{status: :held, variants: []} = Asset.get(id: media.id)
    end

    test "remuxes an H.264 clip and writes a poster", %{user: user} do
      %{id: id} = TestUtils.upload_random_file!(user, :video)

      assert :ok = perform_job(ProcessVideo, %{media_id: id})
      assert_receive %MediaReady{media_id: ^id}

      ready = Asset.get(id: id)

      [video, poster] = ready.variants

      assert {:ok, %{content_type: "video/mp4"}} = Storage.head(video.key)
      assert {:ok, %{content_type: "image/webp"}} = Storage.head(poster.key)
    end

    test "stores the original without its metadata", %{user: user} do
      metadata = [title: "Holiday", location: "+48.8584+002.2945/"]
      media = TestUtils.upload_random_file!(user, :video, metadata: metadata)

      assert :ok = perform_job(ProcessVideo, %{media_id: media.id})

      stored = TestUtils.video_tags!(media.bucket_key)

      refute Map.has_key?(stored, "title")
      refute Map.has_key?(stored, "location")
    end

    @tag :tmp_dir
    test "transcodes to H.264", %{user: user, tmp_dir: dir} do
      media = TestUtils.upload_random_file!(user, :video, format: "webm", size: "1600x1200")

      assert :ok = perform_job(ProcessVideo, %{media_id: media.id})
      assert %Asset{variants: [%{format: :mp4, key: key} | _poster]} = Asset.get(id: media.id)

      path = TestUtils.download_file!(dir, key)

      assert {:ok, %{video_codec: "h264", audio_codec: "aac"}} = Video.probe(path)
    end
  end
end
