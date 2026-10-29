defmodule Hearth.Media.Worker.DeleteMediaTest do
  use Hearth.DataCase, async: true

  alias Hearth.Common
  alias Hearth.Media.Asset
  alias Hearth.Media.Worker.DeleteMedia
  alias Hearth.Media.Worker.ProcessImage
  alias Hearth.Storage
  alias Hearth.TestUtils

  describe "perform/1" do
    test "does nothing for a file already gone" do
      assert :ok = perform_job(DeleteMedia, %{media_id: Common.new_id()})
    end

    test "deletes the file with every size made of it" do
      user = TestUtils.register_random_user!()
      media = TestUtils.upload_random_file!(user, purpose: :avatar)

      :ok = perform_job(ProcessImage, %{media_id: media.id})
      %Asset{variants: [variant | _variants]} = Asset.get(id: media.id)

      assert :ok = perform_job(DeleteMedia, %{media_id: media.id})

      refute Asset.exists?(id: media.id)
      assert {:error, :not_found} = Storage.head(media.bucket_key)
      assert {:error, :not_found} = Storage.head(variant.key)
    end
  end
end
