defmodule Hearth.Forum.ScreeningTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias Hearth.Forum
  alias Hearth.Moderation.Worker.Screen
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    full = TestUtils.create_random_forum!(owner, moderation: :full)
    reports = TestUtils.create_random_forum!(owner, moderation: :reports)
    author = TestUtils.join_random_member!(full)
    {:ok, _membership} = Communities.join(author, reports)
    [kind | _kinds] = Forum.list_kinds(full.id)

    {:ok, binding()}
  end

  describe "create_post/3" do
    test "skips screening if not written", %{
      author: author,
      full: full,
      kind: kind
    } do
      assert {:error, _changeset} =
               Forum.create_post(author, full, %{kind_id: kind.id, title: " "})

      refute_enqueued(worker: Screen)
    end

    test "queues no screening when the write rolls back", %{author: author, full: full} do
      post_id = TestUtils.roll_back_random_post!(author, full)

      refute_enqueued(worker: Screen, args: %{subject_id: post_id})
    end

    test "queues no screening below full", %{author: author, reports: reports} do
      post = TestUtils.create_random_post!(author, reports)

      refute_enqueued(worker: Screen, args: %{subject_id: post.id})
    end

    test "queues screening with the post at full", %{author: author, full: full} do
      post = TestUtils.create_random_post!(author, full)

      assert_enqueued(worker: Screen, args: %{subject_type: "post", subject_id: post.id})
    end
  end

  describe "update_post/3" do
    test "screens the post again after an edit", %{author: author, reports: reports} do
      post = TestUtils.create_random_post!(author, reports)
      :ok = TestUtils.update_rows!(Community, [id: reports.id], moderation: :full)

      assert {:ok, _post} = Forum.update_post(author, post, %{body: Lorem.paragraph()})
      assert_enqueued(worker: Screen, args: %{subject_type: "post", subject_id: post.id})
    end
  end

  describe "reply/3" do
    test "queues no screening below full", %{author: author, reports: reports} do
      post = TestUtils.create_random_post!(author, reports)

      {:ok, reply} = Forum.reply(author, post, %{body: Lorem.sentence()})

      refute_enqueued(worker: Screen, args: %{subject_id: reply.id})
    end

    test "queues screening with the reply at full", %{author: author, full: full} do
      post = TestUtils.create_random_post!(author, full)

      {:ok, reply} = Forum.reply(author, post, %{body: Lorem.sentence()})

      assert_enqueued(worker: Screen, args: %{subject_type: "reply", subject_id: reply.id})
    end
  end

  describe "update_reply/3" do
    test "screens the reply again after an edit", %{author: author, reports: reports} do
      post = TestUtils.create_random_post!(author, reports)
      {:ok, reply} = Forum.reply(author, post, %{body: Lorem.sentence()})
      :ok = TestUtils.update_rows!(Community, [id: reports.id], moderation: :full)

      assert {:ok, _reply} = Forum.update_reply(author, reply, %{body: Lorem.sentence()})
      assert_enqueued(worker: Screen, args: %{subject_type: "reply", subject_id: reply.id})
    end
  end
end
