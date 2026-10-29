defmodule Hearth.Media.Worker.ExpireUploadsTest do
  use Hearth.DataCase, async: true

  alias Hearth.Media
  alias Hearth.Media.Asset
  alias Hearth.Media.Worker.ExpireUploads
  alias Hearth.Storage
  alias Hearth.TestUtils

  setup do
    user = TestUtils.register_random_user!()
    png = TestUtils.random_file!()

    params = TestUtils.random_upload_params()
    {:ok, %{media: media}} = Media.request_upload(user, params)

    :ok = Storage.put(media.bucket_key, png, "image/png")

    {:ok, binding()}
  end

  describe "perform/1" do
    test "leaves an upload started within the hour", %{media: media} do
      assert :ok = perform_job(ExpireUploads, %{})
      assert %Asset{status: :uploading} = Asset.get(id: media.id)
    end

    test "fails unfinished upload", %{media: media} do
      :ok = TestUtils.update_rows!(Asset, [id: media.id], inserted_at: TestUtils.minutes_ago(120))

      assert :ok = perform_job(ExpireUploads, %{})

      assert %Asset{status: :failed} = Asset.get(id: media.id)

      assert {:error, :not_found} = Storage.head(media.bucket_key)
    end
  end
end
