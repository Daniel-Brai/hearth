defmodule Hearth.Forum.Listener.CommunitiesTest do
  use Hearth.DataCase, async: true

  alias Hearth.Communities.CommunityCreated
  alias Hearth.Forum
  alias Hearth.Forum.Listener.Communities, as: Listener
  alias Hearth.TestUtils

  test "ignores other events" do
    assert {:noreply, nil} = Listener.handle_info(:other, nil)
  end

  test "handle community created" do
    community = TestUtils.create_random_community!(nil, template: "club")

    event = %CommunityCreated{
      community_id: community.id,
      owner_id: community.owner_id,
      template: "club"
    }

    assert {:noreply, nil} = Listener.handle_info(event, nil)

    assert [
             %{key: "discussion"},
             %{key: "question"},
             %{key: "photo"},
             %{key: "meetup"},
             %{key: "announcement"}
           ] = Forum.list_kinds(community.id)
  end
end
