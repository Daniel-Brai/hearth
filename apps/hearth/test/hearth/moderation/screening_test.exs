defmodule Hearth.Moderation.ScreeningTest do
  use Hearth.DataCase, async: false

  alias Faker.Lorem
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Moderation
  alias Hearth.Moderation.Item
  alias Hearth.Moderation.ItemQueued
  alias Hearth.Moderation.Screener
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    admin = TestUtils.register_random_user!(admin: true)
    community = TestUtils.create_random_forum!(owner, moderation: :full)
    author = TestUtils.join_random_member!(community)
    :ok = Moderation.subscribe_to_pubsub()

    {:ok, binding()}
  end

  describe "screen/2" do
    test "fails if screener is down", %{
      admin: admin,
      author: author,
      community: community
    } do
      post = TestUtils.create_random_post!(author, community, body: "[down]")

      assert {:error, :not_ready} = Moderation.screen(:post, post.id)
      assert {:ok, %{days: []}} = Moderation.screening_summary(admin)
    end

    test "skips when screening is off", %{author: author, community: community} do
      TestUtils.put_screening(screener: :off)
      post = TestUtils.create_random_post!(author, community, title: "[unsafe]")

      assert {:ok, :skipped} = Moderation.screen(:post, post.id)
    end

    test "skips where the level is below full", %{owner: owner, author: author} do
      community = TestUtils.create_random_forum!(owner, moderation: :reports)
      {:ok, _membership} = Communities.join(author, community)
      post = TestUtils.create_random_post!(author, community, title: "[unsafe]")

      assert {:ok, :skipped} = Moderation.screen(:post, post.id)
    end

    test "leaves content under the threshold up", %{author: author, community: community} do
      post = TestUtils.create_random_post!(author, community, body: "[controversial]")

      assert {:ok, :passed} = Moderation.screen(:post, post.id)
      assert {:ok, %{status: :published}} = Forum.get_post(id: post.id)
    end

    test "holds unsafe content in the community's queue", %{
      admin: admin,
      author: author,
      community: community
    } do
      post = TestUtils.create_random_post!(author, community, body: "[unsafe]")
      post_id = post.id

      assert {:ok, %Item{source: :automatic, held: true, score: 0.95} = item} =
               Moderation.screen(:post, post.id)

      assert item.community_id == community.id
      assert {:ok, %{status: :pending}} = Forum.get_post(id: post.id)
      assert_receive %ItemQueued{subject_id: ^post_id, reporter_id: nil}

      assert {:ok, %{days: [%{screened: 1, held: 1, kept: 0}]}} =
               Moderation.screening_summary(admin)
    end

    test "skips content already held", %{author: author, community: community} do
      post = TestUtils.create_random_post!(author, community, body: "[unsafe]")
      {:ok, _item} = Moderation.screen(:post, post.id)

      assert {:ok, :skipped} = Moderation.screen(:post, post.id)
    end

    test "sends unsafe image to admins", %{
      owner: owner,
      author: author
    } do
      TestUtils.put_screening(image_floor: :images)
      community = TestUtils.create_random_forum!(owner, moderation: :none)
      {:ok, _membership} = Communities.join(author, community)
      image = TestUtils.upload_random_file!(author, data: "unsafe" <> Lorem.sentence())
      post = TestUtils.create_random_post!(author, community, attachment_ids: [image.id])

      assert {:ok, %Item{source: :instance, community_id: nil, held: true}} =
               Moderation.screen(:post, post.id)
    end
  end

  describe "servings/0" do
    test "runs nothing here unless screening is local" do
      TestUtils.put_screening(screener: :hosted)
      assert Moderation.servings() == []

      TestUtils.put_screening(screener: :off)
      assert Moderation.servings() == []
    end

    test "runs the local models when screening is local" do
      TestUtils.put_screening(screener: :local)

      assert Moderation.servings() == [Screener.Local]
    end
  end

  describe "screening_summary/2" do
    test "fails for anyone but an instance admin", %{owner: owner} do
      assert {:error, :forbidden} = Moderation.screening_summary(owner)
    end

    test "counts kept holds as mistakes", %{
      owner: owner,
      admin: admin,
      author: author,
      community: community
    } do
      post = TestUtils.create_random_post!(author, community, body: "[unsafe]")
      {:ok, item} = Moderation.screen(:post, post.id)

      assert {:ok, %Item{status: :kept}} = Moderation.keep(owner, item)
      assert {:ok, %{status: :published}} = Forum.get_post(id: post.id)

      assert {:ok, %{threshold: 0.5, days: [%{held: 1, kept: 1, removed: 0}]}} =
               Moderation.screening_summary(admin)
    end
  end
end
