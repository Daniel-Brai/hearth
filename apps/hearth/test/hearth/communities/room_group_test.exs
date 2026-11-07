defmodule Hearth.Communities.RoomGroupTest do
  use Hearth.DataCase, async: true

  alias Faker.Lorem
  alias Hearth.Communities
  alias Hearth.Communities.Room
  alias Hearth.Communities.RoomLayoutChanged
  alias Hearth.TestUtils

  setup do
    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner)
    member = TestUtils.join_random_member!(community)

    {:ok, binding()}
  end

  describe "create_room_group/3" do
    test "fails if not allowed", %{member: member, community: community} do
      assert {:error, :forbidden} =
               Communities.create_room_group(member, community, %{name: Lorem.word()})
    end

    test "fails past 50 groups", %{owner: owner, community: community} do
      _groups = TestUtils.create_room_groups!(community, 50)

      assert {:error, :too_many_groups} =
               Communities.create_room_group(owner, community, %{name: Lorem.word()})
    end

    test "puts a new group last", %{owner: owner, community: community} do
      _first = TestUtils.create_random_room_group!(community)

      assert {:ok, %{position: 1}} =
               Communities.create_room_group(owner, community, %{name: Lorem.word()})
    end

    test "tells open apps", %{owner: owner, community: community} do
      Communities.subscribe_to_pubsub()

      {:ok, _group} = Communities.create_room_group(owner, community, %{name: Lorem.word()})

      assert_receive %RoomLayoutChanged{}
    end
  end

  describe "list_room_groups/2" do
    test "hides groups of rooms you can't see", %{member: member, community: community} do
      group = TestUtils.create_random_room_group!(community)
      _room = TestUtils.create_random_room!(community, group_id: group.id, access: :roles)
      community = %{community | rooms: Communities.list_visible_rooms(community, member)}

      assert Communities.list_room_groups([community], member) == %{community.id => []}
    end

    test "shows every group to room managers", %{owner: owner, community: community} do
      group = TestUtils.create_random_room_group!(community)
      community = %{community | rooms: Communities.list_visible_rooms(community, owner)}

      assert Communities.list_room_groups([community], owner) == %{community.id => [group]}
    end
  end

  describe "create_room/3" do
    test "fails with another community's group", %{owner: owner, community: community} do
      other = TestUtils.create_random_community!(owner)
      group = TestUtils.create_random_room_group!(other)
      params = %{name: Lorem.word(), group_id: group.id}

      assert {:error, :unknown_group} = Communities.create_room(owner, community, params)
    end

    test "puts the room last in its group", %{community: community} do
      group = TestUtils.create_random_room_group!(community)
      _first = TestUtils.create_random_room!(community, group_id: group.id)

      assert %Room{position: 1} = TestUtils.create_random_room!(community, group_id: group.id)
    end
  end

  describe "update_room/3" do
    test "moves a room last into its new group", %{owner: owner, community: community} do
      group = TestUtils.create_random_room_group!(community)
      _first = TestUtils.create_random_room!(community, group_id: group.id)
      room = TestUtils.create_random_room!(community)

      assert {:ok, moved} = Communities.update_room(owner, room, %{group_id: group.id})
      assert moved.group_id == group.id
      assert moved.position == 1
    end
  end

  describe "arrange_rooms/3" do
    test "fails if not allowed", %{member: member, community: community} do
      layout = %{
        groups: [],
        room_ids: community |> Communities.list_rooms() |> TestUtils.pluck(:id)
      }

      assert {:error, :forbidden} = Communities.arrange_rooms(member, community, layout)
    end

    test "fails if a room is left out", %{owner: owner, community: community} do
      _room = TestUtils.create_random_room!(community)
      general = TestUtils.get_room!(community, slug: "general")
      layout = %{groups: [], room_ids: [general.id]}

      assert {:error, :layout_mismatch} = Communities.arrange_rooms(owner, community, layout)
    end

    test "fails if a room is listed twice", %{owner: owner, community: community} do
      room_ids = community |> Communities.list_rooms() |> TestUtils.pluck(:id)
      layout = %{groups: [], room_ids: room_ids ++ room_ids}

      assert {:error, :layout_mismatch} = Communities.arrange_rooms(owner, community, layout)
    end

    test "moves rooms into groups", %{owner: owner, community: community} do
      group = TestUtils.create_random_room_group!(community)
      room = TestUtils.create_random_room!(community)
      rest = community |> Communities.list_rooms() |> TestUtils.pluck(:id) |> List.delete(room.id)
      layout = %{groups: [%{id: group.id, room_ids: [room.id]}], room_ids: rest}

      assert :ok = Communities.arrange_rooms(owner, community, layout)
      assert %Room{group_id: group_id} = TestUtils.get_room!(community, id: room.id)
      assert group_id == group.id
    end
  end

  describe "delete_room_group/2" do
    test "fails if not allowed", %{member: member, community: community} do
      group = TestUtils.create_random_room_group!(community)

      assert {:error, :forbidden} = Communities.delete_room_group(member, group)
    end

    test "moves its rooms after the others", %{owner: owner, community: community} do
      group = TestUtils.create_random_room_group!(community)
      room = TestUtils.create_random_room!(community, group_id: group.id)

      assert {:ok, _group} = Communities.delete_room_group(owner, group)
      assert %Room{group_id: nil, position: 1} = TestUtils.get_room!(community, id: room.id)
    end
  end
end
