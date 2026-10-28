defmodule Hearth.Media.Listener.AccountsTest do
  use Hearth.DataCase, async: true

  alias Hearth.Accounts.AvatarChanged
  alias Hearth.Common
  alias Hearth.Media.Listener.Accounts, as: Listener
  alias Hearth.Media.Worker.DeleteMedia

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
  end

  test "keeps everything when the first avatar is set" do
    event = %AvatarChanged{
      user_id: Common.new_id(),
      previous_avatar_id: nil,
      avatar_id: Common.new_id()
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    refute_enqueued(worker: DeleteMedia)
  end

  test "deletes the replaced avatar" do
    event = %AvatarChanged{
      user_id: Common.new_id(),
      previous_avatar_id: Common.new_id(),
      avatar_id: nil
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert_enqueued(worker: DeleteMedia, args: %{media_id: event.previous_avatar_id})
  end
end
