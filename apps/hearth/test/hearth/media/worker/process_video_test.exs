defmodule Hearth.Media.Worker.ProcessVideoTest do
  use Hearth.DataCase, async: true

  alias Hearth.Media
  alias Hearth.Media.Asset
  alias Hearth.Media.MediaFailed
  alias Hearth.Media.MediaReady
  alias Hearth.Media.TempFile
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
      media = TestUtils.upload_random_file!(user, TestUtils.random_video!(), "video/mp4")
      :ok = Storage.delete(media.bucket_key)

      assert {:cancel, :missing} = perform_job(ProcessVideo, %{media_id: media.id})
      assert %Asset{status: :failed} = Asset.get(id: media.id)
      assert_receive %MediaFailed{media_id: id} when id == media.id
    end

    test "cancels a file that isn't a video", %{user: user} do
      media = TestUtils.upload_random_file!(user, TestUtils.random_png!(40, 30), "video/mp4")

      assert {:cancel, :unreadable} = perform_job(ProcessVideo, %{media_id: media.id})

      assert %Asset{failure: "The file isn't a video that can be played."} =
               Asset.get(id: media.id)
    end

    test "cancels a video longer than the limit", %{user: user} do
      clip =
        TestUtils.random_video!(
          size: "16x16",
          seconds: 21 * 60,
          codecs: ~w[-c:v libx264 -preset ultrafast -r 1 -an]
        )

      media = TestUtils.upload_random_file!(user, clip, "video/mp4")

      assert {:cancel, :too_long} = perform_job(ProcessVideo, %{media_id: media.id})
      assert %Asset{failure: "The video is longer than 20 minutes."} = Asset.get(id: media.id)
    end

    test "cancels a video bigger than 4K", %{user: user} do
      media =
        TestUtils.upload_random_file!(
          user,
          TestUtils.random_video!(size: "4000x2000", seconds: 1),
          "video/mp4"
        )

      assert {:cancel, :too_big} = perform_job(ProcessVideo, %{media_id: media.id})
    end

    test "does nothing once the row has moved on", %{user: user} do
      media = TestUtils.upload_random_file!(user, TestUtils.random_video!(), "video/mp4")
      {:ok, _media} = Asset.advance(media, :hold)

      assert :ok = perform_job(ProcessVideo, %{media_id: media.id})
      assert %Asset{status: :held, variants: []} = Asset.get(id: media.id)
    end

    test "remuxes an H.264 clip and writes a poster", %{user: user} do
      media = TestUtils.upload_random_file!(user, TestUtils.random_video!(), "video/mp4")

      assert :ok = perform_job(ProcessVideo, %{media_id: media.id})
      assert_receive %MediaReady{media_id: id} when id == media.id

      assert %Asset{status: :ready, width: 320, height: 240, blurhash: blurhash} =
               ready = Asset.get(id: media.id)

      assert ready.duration_ms in 1_900..2_100
      assert is_binary(blurhash)

      assert [%{format: :mp4, key: video_key}, %{format: :webp, width: 320, key: poster_key}] =
               ready.variants

      assert {:ok, %{content_type: "video/mp4"}} = Storage.head(video_key)
      assert {:ok, %{content_type: "image/webp"}} = Storage.head(poster_key)
    end

    test "stores the original without its metadata", %{user: user} do
      tags = ~w[-metadata title=Holiday -metadata location=+48.8584+002.2945/]
      clip = TestUtils.random_video!(codecs: ~w[-c:v libx264 -preset ultrafast -c:a aac] ++ tags)
      media = TestUtils.upload_random_file!(user, clip, "video/mp4")

      assert :ok = perform_job(ProcessVideo, %{media_id: media.id})

      stored = TestUtils.video_tags!(media.bucket_key)

      refute Map.has_key?(stored, "title")
      refute Map.has_key?(stored, "location")

      assert {:ok, %{size: size, content_type: "video/mp4"}} = Storage.head(media.bucket_key)
      assert %Asset{status: :ready, byte_size: ^size} = Asset.get(id: media.id)
    end

    test "transcodes to H.264", %{user: user} do
      clip =
        TestUtils.random_video!(
          size: "1600x1200",
          seconds: 1,
          format: "webm",
          codecs: ~w[-c:v libvpx-vp9 -deadline realtime -cpu-used 8 -c:a libopus]
        )

      media = TestUtils.upload_random_file!(user, clip, "video/webm")

      assert :ok = perform_job(ProcessVideo, %{media_id: media.id})
      assert %Asset{status: :ready, width: 1440, height: 1080} = ready = Asset.get(id: media.id)

      [%{format: :mp4, key: key} | _poster] = ready.variants

      assert {:ok, %{video_codec: "h264", audio_codec: "aac"}} =
               TempFile.run(fn path ->
                 :ok = Storage.download(key, path)
                 Video.probe(path)
               end)
    end
  end
end
