defmodule Hearth.Moderation.Worker.ScreenTest do
  use Hearth.DataCase, async: true

  alias Hearth.Forum
  alias Hearth.Moderation.Worker.Screen
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner, moderation: :full)
    author = TestUtils.join_random_member!(community)

    {:ok, binding()}
  end

  describe "perform/1" do
    test "retries while the screener is down", %{author: author, community: community} do
      post = TestUtils.create_random_post!(author, community, body: "[down]")

      assert {:error, :not_ready} =
               perform_job(Screen, %{subject_type: "post", subject_id: post.id})

      assert {:ok, %{status: :published}} = Forum.get_post(id: post.id)
    end

    test "does nothing below full", %{
      author: author,
      community: community
    } do
      post = TestUtils.create_random_post!(author, community, body: "[unsafe]")

      :ok =
        TestUtils.update_rows!(Hearth.Communities.Community, [id: community.id],
          moderation: :reports
        )

      assert :ok = perform_job(Screen, %{subject_type: "post", subject_id: post.id})
      assert {:ok, %{status: :published}} = Forum.get_post(id: post.id)
    end

    test "holds unsafe content", %{author: author, community: community} do
      post = TestUtils.create_random_post!(author, community, body: "[unsafe]")

      assert :ok = perform_job(Screen, %{subject_type: "post", subject_id: post.id})
      assert {:ok, %{status: :pending}} = Forum.get_post(id: post.id)
    end
  end

  describe "backoff/1" do
    test "waits longer each try" do
      assert Screen.backoff(%Oban.Job{attempt: 1}) == 15
      assert Screen.backoff(%Oban.Job{attempt: 3}) == 60
      assert Screen.backoff(%Oban.Job{attempt: 20}) == 3_600
    end
  end
end
