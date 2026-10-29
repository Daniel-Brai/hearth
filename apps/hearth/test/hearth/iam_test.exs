defmodule Hearth.IAMTest do
  use Hearth.DataCase, async: true

  doctest Hearth.IAM.Spec

  alias Faker.Lorem
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.IAM
  alias Hearth.IAM.Membership
  alias Hearth.IAM.Role
  alias Hearth.TestUtils

  setup do
    %{id: community_id} = TestUtils.create_random_community!()

    roles =
      community_id
      |> IAM.list_roles()
      |> Map.new(&{&1.key, &1})

    {:ok, binding()}
  end

  describe "co_members/2" do
    test "lists shared communities per person" do
      owner = TestUtils.register_random_user!()
      club = TestUtils.create_random_community!(owner)
      garden = TestUtils.create_random_community!(owner)
      member = TestUtils.join_random_member!(club)
      {:ok, _membership} = Communities.join(member, garden)
      _stranger = TestUtils.join_random_member!(TestUtils.create_random_community!())

      co_members = IAM.co_members(owner)

      assert MapSet.new(co_members[member.id]) == MapSet.new([club.id, garden.id])
      assert map_size(co_members) == 1
      assert [_only] = IAM.co_members(owner, club.id)[member.id]
      assert member |> IAM.co_members() |> Map.has_key?(owner.id)
    end
  end

  describe "member_counts/2" do
    test "leaves out people who aren't members" do
      community = TestUtils.create_random_community!()
      outsider = TestUtils.register_random_user!()

      assert IAM.member_counts([community.id], [outsider.id]) == %{}
    end

    test "counts only the given members" do
      community = TestUtils.create_random_community!()
      online = TestUtils.join_random_member!(community)
      _offline = TestUtils.join_random_member!(community)

      assert IAM.member_counts([community.id], [online.id]) == %{community.id => 1}
    end
  end

  describe "shared_community_ids/1" do
    test "lists the communities a person is in" do
      community = TestUtils.create_random_community!()
      member = TestUtils.join_random_member!(community)

      assert IAM.shared_community_ids([member.id]) == [community.id]
    end
  end

  describe "community_ids/1" do
    test "lists none for someone in no community" do
      assert [] = IAM.community_ids(TestUtils.register_random_user!())
    end

    test "lists the communities joined" do
      owner = TestUtils.register_random_user!()
      community = TestUtils.create_random_community!(owner)

      assert IAM.community_ids(owner) == [community.id]
    end
  end

  describe "create_default_roles/1" do
    test "fails if community already has them", %{community_id: community_id} do
      assert {:error, changeset} = IAM.create_default_roles(community_id)
      assert %{key: ["has already been taken"]} = errors_on(changeset)
    end

    test "create default roles", %{roles: roles} do
      assert %{"owner" => owner, "moderator" => moderator, "member" => member} = roles
      assert %Role{is_system: true, position: 0} = owner
      assert %Role{is_default: true} = member
      assert "content.remove" in moderator.permissions
      refute "content.remove" in member.permissions
      assert "post.create" in member.permissions
    end

    test "give mention.all to moderators only", %{roles: roles} do
      assert "mention.all" in roles["moderator"].permissions
      refute "mention.all" in roles["member"].permissions
    end
  end

  describe "create_role/2" do
    test "fails if permission is unknown", %{community_id: community_id} do
      params = %{key: "helper", name: Lorem.word(), permissions: ["post.fly"]}

      assert {:error, changeset} = IAM.create_role(community_id, params)
      assert %{permissions: ["has an invalid entry"]} = errors_on(changeset)
    end

    test "fails if permission is instance wide", %{community_id: community_id} do
      params = %{key: "helper", name: Lorem.word(), permissions: ["community-request.decide"]}

      assert {:error, changeset} = IAM.create_role(community_id, params)
      assert %{permissions: ["has an invalid entry"]} = errors_on(changeset)
    end

    test "fails if key or color is invalid", %{community_id: community_id} do
      params = %{key: "Two Words", name: Lorem.word(), color: "red"}

      assert {:error, changeset} = IAM.create_role(community_id, params)

      assert %{
               key: ["must be lowercase letters, digits and dashes"],
               color: ["must be a hex color"]
             } = errors_on(changeset)
    end

    test "fails if community already has a default role", %{community_id: community_id} do
      params = %{key: "helper", name: Lorem.word(), is_default: true}

      assert {:error, changeset} = IAM.create_role(community_id, params)
      assert %{is_default: ["has already been taken"]} = errors_on(changeset)
    end

    test "create role", %{community_id: community_id} do
      params = %{
        key: "maintainer",
        name: Lorem.word(),
        color: "#3A7BD5",
        position: 1,
        permissions: ["post.pin", "post.pin"]
      }

      assert {:ok, %Role{key: "maintainer", permissions: ["post.pin"]}} =
               IAM.create_role(community_id, params)
    end
  end

  describe "update_role/2" do
    test "ignores key", %{roles: %{"moderator" => moderator}} do
      params = %{key: "mods", name: Lorem.word()}

      assert {:ok, %Role{key: "moderator"} = role} = IAM.update_role(moderator, params)
      assert role.name == params.name
    end

    test "update role", %{roles: %{"member" => member}} do
      assert {:ok, %Role{permissions: ["post.create"]}} =
               IAM.update_role(member, %{permissions: ["post.create"]})
    end
  end

  describe "delete_role/1" do
    test "fails if role is the owner or default", %{roles: roles} do
      assert {:error, :system_role} = IAM.delete_role(roles["owner"])
      assert {:error, :default_role} = IAM.delete_role(roles["member"])
    end

    test "delete role", %{roles: %{"moderator" => moderator}} do
      assert {:ok, _role} = IAM.delete_role(moderator)
      refute Role.get(id: moderator.id)
    end
  end

  describe "join/3" do
    test "fails if already a member", %{community_id: community_id} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(user, community_id)

      assert {:error, changeset} = IAM.join(user, community_id)
      assert %{user_id: ["has already been taken"]} = errors_on(changeset)
    end

    test "joins as default role", %{community_id: community_id, roles: roles} do
      user = TestUtils.register_random_user!()

      assert {:ok, %Membership{roles: []} = membership} = IAM.join(user, community_id)
      assert MapSet.new(membership.permissions) == MapSet.new(roles["member"].permissions)
    end

    test "joins with roles", %{community_id: community_id} do
      user = TestUtils.register_random_user!()

      assert {:ok, %Membership{roles: [%Role{key: "moderator"}]}} =
               IAM.join(user, community_id, ~w[moderator unknown])
    end
  end

  describe "get_membership/2" do
    test "fails if not a member", %{community_id: community_id} do
      assert {:error, :not_found} =
               IAM.get_membership(TestUtils.register_random_user!(), community_id)
    end

    test "owner holds every permission", %{community_id: community_id, roles: roles} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(user, community_id, ["owner"])
      {:ok, _role} = IAM.update_role(roles["owner"], %{permissions: []})

      assert {:ok, %Membership{permissions: permissions}} = IAM.get_membership(user, community_id)
      assert "role.update" in permissions
      refute "community-request.decide" in permissions
    end

    test "adds up permissions of every role", %{community_id: community_id} do
      user = TestUtils.register_random_user!()

      params = %{key: "dj", name: Lorem.word(), permissions: ["voice-session.speak"]}
      {:ok, _role} = IAM.create_role(community_id, params)

      {:ok, _membership} = IAM.join(user, community_id, ~w[member dj])

      assert {:ok, %Membership{permissions: permissions}} = IAM.get_membership(user, community_id)
      assert "voice-session.speak" in permissions
      assert "post.create" in permissions
    end
  end

  describe "set_roles/2" do
    test "set roles", %{community_id: community_id} do
      user = TestUtils.register_random_user!()
      {:ok, membership} = IAM.join(user, community_id, ["moderator"])

      assert {:ok, %Membership{roles: [], permissions: permissions}} =
               IAM.set_roles(membership, [])

      refute "content.remove" in permissions
    end
  end

  describe "leave/2" do
    test "leave", %{community_id: community_id} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(user, community_id)

      assert :ok = IAM.leave(user, community_id)
      refute IAM.member?(user, community_id)
    end
  end

  describe "permissions_for/2" do
    test "returns nothing if not a member", %{community_id: community_id} do
      assert [] = IAM.permissions_for(TestUtils.register_random_user!(), community_id)
    end
  end

  describe "can?/3" do
    test "fails if not a member", %{community_id: community_id} do
      refute IAM.can?(TestUtils.register_random_user!(), :create, %{
               type: :post,
               community_id: community_id
             })
    end

    test "fails if permission is unknown", %{community_id: community_id} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(user, community_id, ["owner"])

      refute IAM.can?(user, :fly, %{type: :post, community_id: community_id})
    end

    test "fails if role lacks permission", %{community_id: community_id} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(user, community_id)

      refute IAM.can?(user, :create, %{type: :"voice.session", community_id: community_id})
      refute IAM.can?(user, :answer, %{type: :post, community_id: community_id})
    end

    test "fails if roles are in another community", %{community_id: community_id} do
      %{id: other_community_id} = TestUtils.create_random_community!()
      user = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(user, other_community_id, ["owner"])

      refute IAM.can?(user, :remove, %{type: :content, community_id: community_id})
    end

    test "fails if instance resource and not an admin" do
      refute IAM.can?(TestUtils.register_random_user!(), :decide, :"community.request")
    end

    test "allows role permission", %{community_id: community_id} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(user, community_id, ["moderator"])

      assert IAM.can?(user, :create, %{type: :"voice.session", community_id: community_id})
    end

    test "allows author on their own things", %{community_id: community_id} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(user, community_id)

      post = %{type: :post, community_id: community_id, author_id: user.id}

      assert IAM.can?(user, :answer, post)
      refute IAM.can?(user, :answer, %{post | author_id: Common.new_id()})
    end

    test "allows instance admin" do
      assert [admin: true]
             |> TestUtils.register_random_user!()
             |> IAM.can?(:decide, :"community.request")
    end
  end
end
