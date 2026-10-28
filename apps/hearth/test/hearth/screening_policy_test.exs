defmodule Hearth.ScreeningPolicyTest do
  use Hearth.DataCase, async: false

  alias Faker.Lorem
  alias Hearth.Chat
  alias Hearth.Common
  alias Hearth.Moderation.Worker.Screen
  alias Hearth.ScreeningPolicy
  alias Hearth.TestUtils

  describe "enqueue/4" do
    test "queues nothing while screening is off" do
      TestUtils.put_screening(screener: :off, image_floor: :images)
      id = Common.new_id()

      assert :ok = ScreeningPolicy.enqueue(:post, id, true, fn -> :full end)
      refute_enqueued(worker: Screen, args: %{subject_id: id})
    end

    test "queues nothing below full" do
      id = Common.new_id()

      assert :ok = ScreeningPolicy.enqueue(:post, id, true, fn -> :reports end)
      refute_enqueued(worker: Screen, args: %{subject_id: id})
    end

    test "skips file check if not screening images" do
      id = Common.new_id()

      assert :ok =
               ScreeningPolicy.enqueue(:post, id, fn -> raise "asked" end, fn -> :none end)
    end

    test "skips level check if files settle it" do
      TestUtils.put_screening(image_floor: :images)
      id = Common.new_id()

      assert :ok = ScreeningPolicy.enqueue(:message, id, true, fn -> raise "read" end)
      assert_enqueued(worker: Screen, args: %{subject_type: "message", subject_id: id})
    end

    test "queues content at full" do
      id = Common.new_id()

      assert :ok = ScreeningPolicy.enqueue(:reply, id, false, fn -> :full end)
      assert_enqueued(worker: Screen, queue: :ai, args: %{subject_type: "reply", subject_id: id})
    end

    test "keeps one waiting job for a burst of edits" do
      id = Common.new_id()

      assert :ok = ScreeningPolicy.enqueue(:post, id, false, fn -> :full end)
      assert :ok = ScreeningPolicy.enqueue(:post, id, false, fn -> :full end)

      assert [_one] = all_enqueued(worker: Screen, args: %{subject_id: id})
    end

    test "screens direct message image" do
      TestUtils.put_screening(image_floor: :images)
      owner = TestUtils.register_random_user!()
      community = TestUtils.create_random_forum!(owner)
      member = TestUtils.join_random_member!(community)
      {:ok, conversation} = Chat.start_direct(member, owner)
      image = TestUtils.upload_random_file!(member, Lorem.sentence(), "image/png")

      {:ok, message} =
        Chat.send_message(member, conversation, %{body: "", attachment_ids: [image.id]})

      assert_enqueued(worker: Screen, args: %{subject_type: "message", subject_id: message.id})
    end
  end

  describe "job/2" do
    test "names worker on ai queue" do
      id = Common.new_id()

      assert %Ecto.Changeset{changes: changes} = ScreeningPolicy.job(:post, id)
      assert %{worker: "Hearth.Moderation.Worker.Screen", queue: "ai"} = changes
      assert changes.args == %{subject_type: :post, subject_id: id}
    end
  end
end
