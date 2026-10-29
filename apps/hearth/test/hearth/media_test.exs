defmodule Hearth.MediaTest do
  use Hearth.DataCase, async: true

  alias Faker.Company
  alias Faker.Lorem
  alias Hearth.Forum
  alias Hearth.Media
  alias Hearth.Media.Asset
  alias Hearth.Media.MediaReady
  alias Hearth.Media.Worker.ProcessImage
  alias Hearth.Media.Worker.ProcessVideo
  alias Hearth.Storage
  alias Hearth.TestUtils

  @pdf "application/pdf"
  @docx "application/vnd.openxmlformats-officedocument.wordprocessingml.document"

  setup do
    :ok = Media.subscribe_to_pubsub()

    {:ok, user: TestUtils.register_random_user!(), png: TestUtils.random_png!(400, 300)}
  end

  describe "share_card_url/1" do
    test "draws the card once and keeps it" do
      card = %{title: Lorem.sentence(), heading: Company.name(), eyebrow: "Question"}

      assert {:ok, url} = Media.share_card_url(card)
      assert {:ok, ^url} = Media.share_card_url(card)

      key = url |> URI.parse() |> Map.fetch!(:path) |> String.replace_prefix("/storage/", "")
      path = Path.join(System.tmp_dir!(), Path.basename(key))
      on_exit(fn -> File.rm(path) end)

      assert :ok = Storage.download(key, path)
      assert {:ok, image} = Image.open(path)
      assert {1200, 630, _bands} = Image.shape(image)
    end

    test "draws a new card when its title changes" do
      card = %{title: Lorem.sentence(), heading: Company.name()}

      assert {:ok, url} = Media.share_card_url(card)
      assert {:ok, other} = Media.share_card_url(%{card | title: Lorem.sentence()})
      refute URI.parse(url).path == URI.parse(other).path
    end
  end

  describe "put_attachments/4" do
    setup %{user: user} do
      community = TestUtils.create_random_community!(user, template: "oss")
      {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)

      {:ok, post: TestUtils.create_random_post!(user, community)}
    end

    test "fails for someone else's file", %{user: user, post: post} do
      [theirs] = TestUtils.upload_random_attachments!(TestUtils.register_random_user!(), 1)

      assert {:error, :invalid_attachment} =
               Media.put_attachments(user, :post, post.id, [theirs.id])
    end

    test "fails for an unfinished upload", %{user: user, post: post, png: png} do
      [unfinished] = TestUtils.request_random_uploads!(user, png, "image/png", 1)

      assert {:error, :invalid_attachment} =
               Media.put_attachments(user, :post, post.id, [unfinished.id])
    end

    test "fails for an avatar", %{user: user, post: post, png: png} do
      avatar = TestUtils.upload_random_file!(user, png, "image/png", purpose: :avatar)

      assert {:error, :invalid_attachment} =
               Media.put_attachments(user, :post, post.id, [avatar.id])
    end

    test "fails for more than 10 files", %{user: user, post: post} do
      ids = TestUtils.random_ids(11)

      assert {:error, :too_many_attachments} = Media.put_attachments(user, :post, post.id, ids)
    end

    test "keeps the files in order", %{user: user, post: post} do
      [first, second] = TestUtils.upload_random_attachments!(user, 2)

      assert :ok = Media.put_attachments(user, :post, post.id, [second.id, first.id])

      %{id: post_id} = post
      %{id: first_id} = first
      %{id: second_id} = second

      assert %{^post_id => [%{media: %{id: ^second_id}}, %{media: %{id: ^first_id}}]} =
               Media.list_attachments(:post, [post.id])
    end

    test "replaces the files it had", %{user: user, post: post} do
      [first, second] = TestUtils.upload_random_attachments!(user, 2)
      :ok = Media.put_attachments(user, :post, post.id, [first.id])

      assert :ok = Media.put_attachments(user, :post, post.id, [second.id])

      post_id = post.id
      media_id = second.id

      assert %{^post_id => [%{media_id: ^media_id}]} = Media.list_attachments(:post, [post.id])
      assert {:ok, _kept} = Media.get_media(first.id)
    end
  end

  describe "request_upload/2" do
    test "fails for a type that can't be uploaded", %{user: user} do
      params = TestUtils.random_upload_params("MZ", "application/x-msdownload")

      assert {:error, changeset} = Media.request_upload(user, params)
      assert %{content_type: ["is not a type that can be uploaded"]} = errors_on(changeset)
    end

    test "fails for a file over the limit", %{user: user, png: png} do
      params = TestUtils.random_upload_params(png, "image/png", byte_size: 11 * 1024 * 1024)

      assert {:error, changeset} = Media.request_upload(user, params)
      assert %{byte_size: [_too_big]} = errors_on(changeset)
    end

    test "fails for a video over 100 MB", %{user: user} do
      params = TestUtils.random_upload_params("", "video/mp4", byte_size: 101 * 1024 * 1024)

      assert {:error, changeset} = Media.request_upload(user, params)
      assert %{byte_size: [_too_big]} = errors_on(changeset)
    end

    test "fails for a video said to be over 20 minutes", %{user: user} do
      params = TestUtils.random_upload_params("clip", "video/mp4", duration_ms: 21 * 60_000)

      assert {:error, changeset} = Media.request_upload(user, params)
      assert %{duration_ms: [_too_long]} = errors_on(changeset)
    end

    test "fails for a checksum that isn't hex SHA-256", %{user: user, png: png} do
      params = TestUtils.random_upload_params(png, "image/png", sha256: "nope")

      assert {:error, changeset} = Media.request_upload(user, params)
      assert %{sha256: ["is not a SHA-256 in hex"]} = errors_on(changeset)
    end

    test "fails with 20 unfinished uploads", %{user: user, png: png} do
      _media = TestUtils.request_random_uploads!(user, png, "image/png", 20)

      assert {:error, :too_many_unfinished} =
               Media.request_upload(user, TestUtils.random_upload_params(png, "image/png"))
    end

    test "fails after 60 uploads in an hour", %{user: user, png: png} do
      :ok = TestUtils.fail_random_uploads!(user, png, "image/png", 60)

      assert {:error, :rate_limited} =
               Media.request_upload(user, TestUtils.random_upload_params(png, "image/png"))
    end

    test "signs one PUT for a small file", %{user: user, png: png} do
      params = TestUtils.random_upload_params(png, "image/png")

      assert {:ok, %{media: media, upload: %{url: url, headers: headers}}} =
               Media.request_upload(user, params)

      assert %Asset{status: :uploading, multipart_upload_id: nil} = media
      assert media.bucket_key == "media/#{media.id}/original"
      assert url =~ media.bucket_key
      assert headers["content-type"] == "image/png"
    end

    test "starts a multipart upload for a big file", %{user: user} do
      params = TestUtils.random_upload_params("", @pdf, byte_size: 3 * 1024 * 1024)

      assert {:ok, %{media: media, upload: %{upload_id: upload_id, parts: 1}}} =
               Media.request_upload(user, params)

      assert media.multipart_upload_id == upload_id
    end

    test "returns the same row for the same key", %{user: user, png: png} do
      params = TestUtils.random_upload_params(png, "image/png")

      {:ok, %{media: %{id: id}}} = Media.request_upload(user, params)

      assert {:ok, %{media: %Asset{id: ^id}, upload: %{url: _url}}} =
               Media.request_upload(user, params)
    end
  end

  describe "part_urls/3" do
    setup %{user: user} do
      params = TestUtils.random_upload_params("", @pdf, byte_size: 25 * 1024 * 1024)
      {:ok, %{media: media}} = Media.request_upload(user, params)

      {:ok, binding()}
    end

    test "fails for someone else", %{media: media} do
      assert {:error, :forbidden} = Media.part_urls(TestUtils.register_random_user!(), media, [1])
    end

    test "fails for a single upload", %{user: user, png: png} do
      {:ok, %{media: media}} =
        Media.request_upload(user, TestUtils.random_upload_params(png, "image/png"))

      assert {:error, :not_multipart} = Media.part_urls(user, media, [1])
    end

    test "fails for a part past the end", %{user: user, media: media} do
      assert {:error, :invalid_part} = Media.part_urls(user, media, [0])
      assert {:error, :invalid_part} = Media.part_urls(user, media, [4])
    end

    test "signs each part", %{user: user, media: media} do
      assert {:ok, %{1 => first_url, 3 => third_url}} = Media.part_urls(user, media, [1, 3])
      assert first_url != third_url
    end
  end

  describe "list_parts/2" do
    test "fails for someone else", %{user: user} do
      params = TestUtils.random_upload_params("", @pdf, byte_size: 3 * 1024 * 1024)
      {:ok, %{media: media}} = Media.request_upload(user, params)

      assert {:error, :forbidden} = Media.list_parts(TestUtils.register_random_user!(), media)
    end

    test "lists the parts already stored", %{user: user} do
      params = TestUtils.random_upload_params("", @pdf, byte_size: 3 * 1024 * 1024)
      {:ok, %{media: media}} = Media.request_upload(user, params)

      {:ok, _etag} =
        Storage.write_local_part(media.bucket_key, media.multipart_upload_id, 1, ["%PDF-"])

      assert {:ok, [%{number: 1, size: 5}]} = Media.list_parts(user, media)
    end
  end

  describe "complete_upload/3" do
    test "fails for someone else", %{user: user, png: png} do
      {:ok, %{media: media}} =
        Media.request_upload(user, TestUtils.random_upload_params(png, "image/png"))

      assert {:error, :forbidden} =
               Media.complete_upload(TestUtils.register_random_user!(), media)
    end

    test "fails before the file is stored", %{user: user, png: png} do
      {:ok, %{media: media}} =
        Media.request_upload(user, TestUtils.random_upload_params(png, "image/png"))

      assert {:error, :not_uploaded} = Media.complete_upload(user, media)
      assert %Asset{status: :uploading} = Asset.get(id: media.id)
    end

    test "fails and deletes a file of another size", %{user: user, png: png} do
      {:ok, %{media: media}} =
        Media.request_upload(user, TestUtils.random_upload_params(png, "image/png"))

      :ok = Storage.put(media.bucket_key, png <> "more", "image/png")

      assert {:error, :mismatch} = Media.complete_upload(user, media)
      assert %Asset{status: :failed, failure: "The file isn't" <> _rest} = Asset.get(id: media.id)
      assert {:error, :not_found} = Storage.head(media.bucket_key)
    end

    test "fails a program named as a PDF", %{user: user} do
      data = "MZ" <> :binary.copy(<<0>>, 64)

      {:ok, %{media: media}} =
        Media.request_upload(user, TestUtils.random_upload_params(data, @pdf))

      :ok = Storage.put(media.bucket_key, data, @pdf)

      assert {:error, :content_mismatch} = Media.complete_upload(user, media)
      assert %Asset{status: :failed} = Asset.get(id: media.id)
    end

    test "fails again once failed", %{user: user, png: png} do
      {:ok, %{media: media}} =
        Media.request_upload(user, TestUtils.random_upload_params(png, "image/png"))

      :ok = Storage.put(media.bucket_key, "short", "image/png")
      {:error, :mismatch} = Media.complete_upload(user, media)

      assert {:error, :failed} = Media.complete_upload(user, Asset.get(id: media.id))
    end

    test "queues an image to be processed", %{user: user, png: png} do
      assert %Asset{id: id, status: :processing} =
               TestUtils.upload_random_file!(user, png, "image/png")

      assert_enqueued(worker: ProcessImage, args: %{media_id: id})
      refute_receive %MediaReady{media_id: ^id}
    end

    test "queues a video to be processed", %{user: user} do
      assert %Asset{id: id, status: :processing} =
               TestUtils.upload_random_file!(user, TestUtils.random_video!(), "video/mp4")

      assert_enqueued(worker: ProcessVideo, args: %{media_id: id})
    end

    test "makes a document ready", %{user: user} do
      {:ok, {_name, docx}} =
        :zip.create(~c"file.docx", [{~c"word/document.xml", "<w:document/>"}], [:memory])

      assert %Asset{id: id, status: :ready} = TestUtils.upload_random_file!(user, docx, @docx)
      assert_receive %MediaReady{media_id: ^id}
    end

    test "completes a multipart upload", %{user: user} do
      data = "%PDF-" <> :binary.copy("x", 2 * 1024 * 1024)

      {:ok, %{media: media}} =
        Media.request_upload(user, TestUtils.random_upload_params(data, @pdf))

      {:ok, etag} =
        Storage.write_local_part(media.bucket_key, media.multipart_upload_id, 1, [data])

      assert {:ok, %Asset{status: :ready, multipart_upload_id: nil}} =
               Media.complete_upload(user, media, [{1, etag}])

      size = byte_size(data)

      assert {:ok, %{size: ^size}} = Storage.head(media.bucket_key)
    end

    test "returns the row again once completed", %{user: user, png: png} do
      media = TestUtils.upload_random_file!(user, png, "image/png")

      assert {:ok, %Asset{status: :processing}} = Media.complete_upload(user, media)
    end
  end

  describe "urls/1" do
    test "has none until ready", %{user: user, png: png} do
      assert user |> TestUtils.upload_random_file!(png, "image/png") |> Media.urls() == nil
    end

    test "signs the original and each size", %{user: user, png: png} do
      media = TestUtils.upload_random_file!(user, png, "image/png")
      :ok = perform_job(ProcessImage, %{media_id: media.id})

      assert %{original: original, variants: [%{width: 320, format: :webp, url: url}]} =
               [id: media.id] |> Asset.get() |> Media.urls()

      assert original =~ "original"
      assert url =~ "w320.webp"
    end

    test "saves a picture as it was sent", %{user: user, png: png} do
      media = TestUtils.upload_random_file!(user, png, "image/png", name: "harbour.png")
      :ok = perform_job(ProcessImage, %{media_id: media.id})

      %{download: download} = [id: media.id] |> Asset.get() |> Media.urls()

      %URI{path: path, query: query} = URI.parse(download)

      assert path =~ "original"
      assert %{"dl" => "harbour.png"} = URI.decode_query(query)
    end

    test "saves a document as it was sent", %{user: user} do
      {:ok, {_name, docx}} =
        :zip.create(~c"file.docx", [{~c"word/document.xml", "<w:document/>"}], [:memory])

      media = TestUtils.upload_random_file!(user, docx, @docx, name: "notes.docx")

      %{download: download} = Media.urls(media)

      %URI{path: path, query: query} = URI.parse(download)

      assert path =~ "original"
      assert %{"dl" => "notes.docx"} = URI.decode_query(query)
    end
  end

  describe "delete_media/2" do
    test "fails for someone else", %{user: user, png: png} do
      media = TestUtils.upload_random_file!(user, png, "image/png")

      assert {:error, :forbidden} = Media.delete_media(TestUtils.register_random_user!(), media)
    end

    test "deletes the row and its files", %{user: user, png: png} do
      media = TestUtils.upload_random_file!(user, png, "image/png")
      :ok = perform_job(ProcessImage, %{media_id: media.id})

      assert {:ok, _media} = Media.delete_media(user, media)
      assert Asset.get(id: media.id) == nil
      assert {:error, :not_found} = Storage.head(media.bucket_key)
      assert {:error, :not_found} = Storage.head("media/#{media.id}/w320.webp")
    end
  end

  describe "avatar?/2" do
    test "is false if not own avatar", %{
      user: user,
      png: png
    } do
      avatar =
        TestUtils.upload_random_file!(TestUtils.register_random_user!(), png, "image/png",
          purpose: :avatar
        )

      image = TestUtils.upload_random_file!(user, png, "image/png")

      refute Media.avatar?(user, avatar.id)
      refute Media.avatar?(user, image.id)
    end

    test "is true for own avatar", %{user: user, png: png} do
      avatar = TestUtils.upload_random_file!(user, png, "image/png", purpose: :avatar)

      assert Media.avatar?(user, avatar.id)
    end
  end

  describe "avatar_urls/1" do
    test "signs only ready avatars", %{user: user, png: png} do
      ready = TestUtils.upload_random_file!(user, png, "image/png", purpose: :avatar)
      waiting = TestUtils.upload_random_file!(user, png, "image/png", purpose: :avatar)
      :ok = perform_job(ProcessImage, %{media_id: ready.id})

      assert [ready.id] == [ready.id, waiting.id, nil] |> Media.avatar_urls() |> Map.keys()
    end
  end

  describe "image_urls/2" do
    test "leaves out images that aren't ready", %{user: user, png: png} do
      waiting = TestUtils.upload_random_file!(user, png, "image/png")

      assert Media.image_urls([waiting.id, nil], 0) == %{}
    end

    test "signs smallest wide enough size", %{user: user} do
      wide = TestUtils.random_png!(1400, 400)
      image = TestUtils.upload_random_file!(user, wide, "image/png")
      :ok = perform_job(ProcessImage, %{media_id: image.id})

      small = Media.image_urls([image.id], 0)[image.id]
      large = Media.image_urls([image.id], 1280)[image.id]

      assert small =~ "320"
      assert large =~ "1280"
      assert Media.image_urls([image.id], 5000)[image.id] == large
    end
  end
end
