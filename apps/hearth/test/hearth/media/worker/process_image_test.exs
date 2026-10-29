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
      media = TestUtils.upload_random_file!(user)
      :ok = Storage.delete(media.bucket_key)

      assert {:cancel, :missing} = perform_job(ProcessImage, %{media_id: media.id})
      assert_receive %MediaFailed{media_id: id} when id == media.id
    end

    test "cancels a file that isn't an image", %{user: user} do
      media = TestUtils.upload_random_file!(user, data: "just some text")

      assert {:cancel, :unreadable} = perform_job(ProcessImage, %{media_id: media.id})
    end

    test "cancels oversize image", %{user: user} do
      <<signature::binary-8, length::binary-4, "IHDR", _size::binary-8, rest::binary-5,
        _crc::binary-4, chunks::binary>> = TestUtils.random_file!(:png, width: 10, height: 10)

      header = <<"IHDR", 8000::32, 7000::32, rest::binary>>
      png = signature <> length <> header <> <<:erlang.crc32(header)::32>> <> chunks

      media = TestUtils.upload_random_file!(user, data: png)

      assert {:cancel, :too_many_pixels} = perform_job(ProcessImage, %{media_id: media.id})
    end

    test "does nothing once the row has moved on", %{user: user} do
      %{id: id} = media = TestUtils.upload_random_file!(user)

      {:ok, _media} = Asset.advance(media, :hold)

      assert :ok = perform_job(ProcessImage, %{media_id: id})
      assert %Asset{status: :held, variants: []} = Asset.get(id: id)
      refute_receive %MediaReady{media_id: ^id}
    end

    test "writes each size up to the image's width", %{user: user} do
      media = TestUtils.upload_random_file!(user, width: 2100, height: 1050)

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})

      assert %Asset{variants: [%{width: 320} = smallest, _w640, _w1280, %{width: 2048} = largest]} =
               Asset.get(id: media.id)

      assert {:ok, %{content_type: "image/webp"}} = Storage.head(smallest.key)
      assert {:ok, %{content_type: "image/webp"}} = Storage.head(largest.key)
    end

    test "rotates original and strips metadata", %{user: user} do
      photo = TestUtils.photo_with_metadata!(400, 200)
      media = TestUtils.upload_random_file!(user, data: photo, content_type: "image/jpeg")

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})

      stored = TestUtils.stored_image!(media.bucket_key)

      assert {Image.width(stored), Image.height(stored)} == {200, 400}
      assert {:error, _none} = Vimage.header_value(stored, "exif-data")
      assert {:error, _none} = Vimage.header_value(stored, "orientation")
    end

    test "keeps a small image at its own width", %{user: user} do
      media = TestUtils.upload_random_file!(user, width: 200, height: 100)

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})
      assert %Asset{variants: [%{width: 200, height: 100}]} = Asset.get(id: media.id)
    end

    test "crops an avatar square", %{user: user} do
      media = TestUtils.upload_random_file!(user, width: 800, height: 400, purpose: :avatar)

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})
      assert %Asset{variants: [%{width: 320, height: 320}]} = Asset.get(id: media.id)
    end

    test "runs again without making copies", %{user: user} do
      media = TestUtils.upload_random_file!(user, width: 700, height: 350)

      :ok = perform_job(ProcessImage, %{media_id: media.id})

      ready = Asset.get(id: media.id)
      {:ok, _media} = Asset.transition(ready, :ready, status: :processing)

      assert :ok = perform_job(ProcessImage, %{media_id: media.id})
      %Asset{variants: variants} = Asset.get(id: media.id)

      assert length(variants) == 2
    end
  end
end
