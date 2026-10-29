defmodule Hearth.Notifications.DigestTest do
  use Hearth.DataCase, async: true

  alias Hearth.Forum
  alias Hearth.Moderation
  alias Hearth.Notifications.CatchUp
  alias Hearth.Notifications.Digest
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_forum!(owner, moderation: :reports)
    reader = TestUtils.join_random_member!(community)
    since = TestUtils.days_ago(1)

    {:ok, binding()}
  end

  describe "build/3" do
    test "is nil with nothing new", %{reader: reader, since: since} do
      refute Digest.build(reader, :daily, since)
    end

    test "leaves out own and opened posts", %{
      reader: reader,
      community: community,
      owner: owner,
      since: since
    } do
      _own = TestUtils.create_random_post!(reader, community)
      opened = TestUtils.create_random_post!(owner, community)
      :ok = Forum.mark_seen(reader, opened)

      refute Digest.build(reader, :daily, since)
    end

    test "leaves out communities the reader didn't join", %{reader: reader, since: since} do
      other = TestUtils.create_random_forum!()
      _post = other |> TestUtils.join_random_member!() |> TestUtils.create_random_post!(other)

      refute Digest.build(reader, :daily, since)
    end

    test "leaves out removed and held posts", %{
      reader: reader,
      community: community,
      owner: owner,
      since: since
    } do
      {:ok, _removed} =
        owner |> TestUtils.create_random_post!(community) |> Forum.moderate(:removed)

      {:ok, _held} = owner |> TestUtils.create_random_post!(community) |> Forum.moderate(:pending)

      refute Digest.build(reader, :daily, since)
    end

    test "leaves out posts waiting on a report", %{
      reader: reader,
      community: community,
      owner: owner,
      since: since
    } do
      post = TestUtils.create_random_post!(owner, community)
      {:ok, _item} = Moderation.report(reader, :post, post.id, %{reason: :spam})

      refute Digest.build(reader, :daily, since)
    end

    test "leaves out posts from before", %{reader: reader, community: community, owner: owner} do
      _post = TestUtils.create_random_post!(owner, community)

      refute Digest.build(reader, :daily, DateTime.add(DateTime.utc_now(), 1, :minute))
    end

    test "shows best three and counts rest", %{
      reader: reader,
      community: community,
      owner: owner,
      since: since
    } do
      [best | _rest] = TestUtils.create_random_posts!(owner, community, 5)
      {:ok, :marked} = Forum.toggle_helpful(reader, best)

      assert %CatchUp{communities: [entry]} = Digest.build(reader, :weekly, since)
      assert [top | _rest] = entry.posts
      assert top.post.id == best.id
      assert length(entry.posts) == 3
      assert entry.more == 2
    end
  end
end
