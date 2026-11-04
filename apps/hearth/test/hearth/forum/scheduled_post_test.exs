defmodule Hearth.Forum.ScheduledPostTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Forum.PostCreated
  alias Hearth.Forum.ScheduledPostChanged
  alias Hearth.Forum.Worker.PublishScheduled
  alias Hearth.TestUtils

  setup do
    :ok = Forum.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")
    {:ok, _kinds} = Forum.create_default_kinds(community.id, community.template)

    member = TestUtils.register_random_user!()
    {:ok, _membership} = Communities.join(member, community)

    kinds =
      community.id
      |> Forum.list_kinds()
      |> Map.new(&{&1.key, &1})

    {:ok, binding()}
  end

  describe "schedule_post/3" do
    test "fails if not a member", %{community: community, kinds: kinds} do
      params = %{
        kind_id: kinds["question"].id,
        title: Lorem.sentence(),
        send_at: TestUtils.in_minutes(30)
      }

      assert {:error, :forbidden} =
               Forum.schedule_post(TestUtils.register_random_user!(), community, params)
    end

    test "fails if kind belongs to another community", %{member: member, community: community} do
      other = TestUtils.create_random_community!()
      {:ok, [kind | _kinds]} = Forum.create_default_kinds(other.id, "blank")
      params = %{kind_id: kind.id, title: Lorem.sentence(), send_at: TestUtils.in_minutes(30)}

      assert {:error, :unknown_kind} = Forum.schedule_post(member, community, params)
    end

    test "fails for a time already past", %{member: member, community: community, kinds: kinds} do
      params = %{
        kind_id: kinds["question"].id,
        title: Lorem.sentence(),
        send_at: TestUtils.in_minutes(-5)
      }

      assert {:error, changeset} = Forum.schedule_post(member, community, params)
      assert %{send_at: ["must be at least a minute from now"]} = errors_on(changeset)
    end

    test "waits until its time", %{member: member, community: community, kinds: kinds} do
      params = %{
        kind_id: kinds["question"].id,
        title: Lorem.sentence(),
        send_at: TestUtils.in_minutes(30)
      }

      community_id = community.id
      assert {:ok, %{id: id}} = Forum.schedule_post(member, community, params)
      assert_enqueued(worker: PublishScheduled, args: %{scheduled_id: id})
      assert_receive %ScheduledPostChanged{scheduled_id: ^id}
      refute_receive %PostCreated{community_id: ^community_id}
    end
  end

  describe "publish_scheduled/1" do
    test "fails once the author can't post there", %{member: member, community: community} do
      scheduled = TestUtils.schedule_random_post!(member, community)
      :ok = Communities.leave(member, community)

      assert {:error, :forbidden} = Forum.publish_scheduled(scheduled)
      assert {:ok, %{failure: "forbidden"}} = Forum.get_scheduled_post(member, scheduled.id)
    end

    test "posts as the author and stops waiting", %{member: member, community: community} do
      scheduled = TestUtils.schedule_random_post!(member, community)

      assert {:ok, %{author_id: author_id, title: title}} = Forum.publish_scheduled(scheduled)
      assert author_id == member.id
      assert title == scheduled.title
      assert {:error, :not_found} = Forum.get_scheduled_post(member, scheduled.id)
    end
  end

  describe "reschedule_post/2" do
    test "fails for a time already past", %{member: member, community: community} do
      scheduled = TestUtils.schedule_random_post!(member, community)

      assert {:error, _changeset} = Forum.reschedule_post(scheduled, TestUtils.in_minutes(-1))
    end

    test "moves it to the new time", %{member: member, community: community} do
      scheduled = TestUtils.schedule_random_post!(member, community)
      send_at = TestUtils.in_minutes(90)

      assert {:ok, moved} = Forum.reschedule_post(scheduled, send_at)
      assert moved.send_at == send_at
    end
  end

  describe "cancel_scheduled_post/1" do
    test "stops it waiting", %{member: member, community: community} do
      scheduled = TestUtils.schedule_random_post!(member, community)

      assert :ok = Forum.cancel_scheduled_post(scheduled)
      assert {:error, :not_found} = Forum.get_scheduled_post(member, scheduled.id)
    end
  end

  describe "perform/1" do
    test "does nothing for a time that moved", %{member: member, community: community} do
      scheduled = TestUtils.schedule_random_post!(member, community)
      {:ok, _moved} = Forum.reschedule_post(scheduled, TestUtils.in_minutes(60))
      args = %{scheduled_id: scheduled.id, send_at: DateTime.to_iso8601(scheduled.send_at)}

      community_id = community.id
      assert :ok = perform_job(PublishScheduled, args)
      refute_receive %PostCreated{community_id: ^community_id}
    end

    test "publishes the post at its time", %{member: member, community: community} do
      scheduled = TestUtils.schedule_random_post!(member, community)
      args = %{scheduled_id: scheduled.id, send_at: DateTime.to_iso8601(scheduled.send_at)}
      member_id = member.id

      assert :ok = perform_job(PublishScheduled, args)
      assert_receive %PostCreated{author_id: ^member_id}
    end
  end
end
