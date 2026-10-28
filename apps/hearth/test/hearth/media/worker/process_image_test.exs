defmodule Hearth.Media.Worker.ProcessImageTest do
  use Hearth.DataCase, async: true

  alias Hearth.Media
  alias Hearth.Media.Asset
  alias Hearth.Media.MediaFailed
  alias Hearth.Media.MediaReady
  alias Hearth.Media.Worker.ProcessImage
  alias Hearth.Storage
  alias Hearth.TestUtils
  alias Vix.Vips.Image, as: Vimage

  setup do
    :ok = Media.subscribe_to_pubsub()

    {:ok, user: TestUtils.register_random_user!()}
  end

  describe "perform/1" do
    test "cancels when the original is gone", %{user: user} do
      media = TestUtils.upload_random_file!(user, TestUtils.random_png!(400, 300), "image/png")
      :ok = Storage.delete(media.bucket_key)

      assert {:cancel, :missing} = perform_job(ProcessImage, %{media_id: media.id})
      assert %Asset{status: :failed} = Asset.get(id: media.id)
      assert_receive %MediaFailed{media_id: id} when id == media.id
    end

    test "cancels a file that isn't an image", %{user: user} do
      media = TestUtils.upload_random_file!(user, "just some text", "image/png")

      assert {:cancel, :unreadable} = perform_job(ProcessImage, %{media_id: media.id})
      assert %Asset{status: :failed} = Asset.get(id: media.id)
    end

    test "cancels oversize image", %{user: user} do
      <<signature::binary-8, length::binary-4, "IHDR", _size::binary-8, rest::binary-5,
        _crc::binary-4, chunks::binary>> = TestUtils.random_png!(10, 10)

      header = <<"IHDR", 8000::32, 7000::32, rest::binary>>
      png = signature <> length <> header <> <<:erlang.crc32(header)::32>> <> chunks

      media = TestUtils.upload_random_file!(user, png, "image/png")

      assert {:cancel, :too_many_pixels} = perform_job(ProcessImage, %{media_id: media.id})
      assert %Asset{failure: "The image is bigger than 50 megapixels."} = Asset.get(id: media.id)
    end

    test "does nothing once the row has moved on", %{user: user} do
      %{id: id} =
        media = TestUtils.upload_random_file!(user, TestUtils.random_png!(400, 300), "image/png")

      {:ok, _media} = Asset.advance(media, :hold)

      assert :ok = perform_job(ProcessImage, %{media_id: id})
      assert %Asset{status: :held, variants: []} = Asset.get(id: id)
      refute_receive %MediaReady{media_id: ^id}
    end

    test "writes each size up to the image's width", %{user: user} do
      media = TestUtils.upload_random_file!(user, TestUtils.random_png!(2100, 1050), "image/png")

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})
      assert_receive %MediaReady{media_id: id} when id == media.id

      assert %Asset{status: :ready, width: 2048, height: 1024, blurhash: blurhash} =
               ready = Asset.get(id: media.id)

      assert is_binary(blurhash)

      assert [
               %{width: 320, height: 160} = smallest,
               %{width: 640, height: 320},
               %{width: 1280, height: 640},
               %{width: 2048, height: 1024} = largest
             ] = ready.variants

      assert {:ok, %{content_type: "image/webp"}} = Storage.head(smallest.key)
      assert {:ok, %{content_type: "image/webp"}} = Storage.head(largest.key)
    end

    test "stores the original upright and without its metadata", %{user: user} do
      photo = TestUtils.photo_with_metadata!(400, 200)
      media = TestUtils.upload_random_file!(user, photo, "image/jpeg")

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})

      stored = TestUtils.stored_image!(media.bucket_key)

      assert {Image.width(stored), Image.height(stored)} == {200, 400}
      assert {:error, _none} = Vimage.header_value(stored, "exif-data")
      assert {:error, _none} = Vimage.header_value(stored, "orientation")

      assert {:ok, %{size: size, content_type: "image/jpeg"}} = Storage.head(media.bucket_key)
      assert %Asset{byte_size: ^size} = Asset.get(id: media.id)
    end

    test "keeps a small image at its own width", %{user: user} do
      media = TestUtils.upload_random_file!(user, TestUtils.random_png!(200, 100), "image/png")

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})
      assert %Asset{variants: [%{width: 200, height: 100}]} = Asset.get(id: media.id)
    end

    test "crops an avatar square", %{user: user} do
      media =
        TestUtils.upload_random_file!(user, TestUtils.random_png!(800, 400), "image/png",
          purpose: :avatar
        )

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})
      assert %Asset{variants: [%{width: 320, height: 320}]} = Asset.get(id: media.id)
    end

    test "runs again without making copies", %{user: user} do
      media = TestUtils.upload_random_file!(user, TestUtils.random_png!(700, 350), "image/png")
      :ok = perform_job(ProcessImage, %{media_id: media.id})

      {:ok, _media} =
        [id: media.id] |> Asset.get() |> Asset.transition(:ready, status: :processing)

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})
      assert %Asset{variants: [_w320, _w640]} = Asset.get(id: media.id)
    end
  end
end
