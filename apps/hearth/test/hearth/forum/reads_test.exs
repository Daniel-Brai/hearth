defmodule Hearth.Forum.ReadsTest do
  use Hearth.DataCase, async: true

  alias Hearth.Forum.PostRead
  alias Hearth.Forum.Reads
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner)
    post = TestUtils.create_random_post!(owner, community)

    {:ok, binding()}
  end

  describe "flush/1" do
    test "keeps a newer read over an older one", %{owner: owner, post: post} do
      now = System.os_time(:microsecond)
      key = {owner.id, post.id}

      assert :ok = Reads.flush([{key, 5, now, 1}])
      assert :ok = Reads.flush([{key, 2, now - 1_000_000, 1}])

      assert %PostRead{seen_reply_count: 5} = PostRead.get(user_id: owner.id, post_id: post.id)
    end

    test "moves a read forward", %{owner: owner, post: post} do
      now = System.os_time(:microsecond)
      key = {owner.id, post.id}

      assert :ok = Reads.flush([{key, 2, now - 1_000_000, 1}])
      assert :ok = Reads.flush([{key, 5, now, 1}])

      assert %PostRead{seen_reply_count: 5} = PostRead.get(user_id: owner.id, post_id: post.id)
    end
  end
end
