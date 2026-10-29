defmodule Hearth.CommunitiesTest do
  use Hearth.DataCase, async: true

  alias Faker.Company
  alias Faker.Internet
  alias Faker.Lorem
  alias Hearth.Auth
  alias Hearth.Auth.TransferCodeRequested
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Communities.Ban
  alias Hearth.Communities.Community
  alias Hearth.Communities.CommunityCreated
  alias Hearth.Communities.Invite
  alias Hearth.Communities.InviteEmail
  alias Hearth.Communities.InvitesEmailed
  alias Hearth.Communities.MemberBanned
  alias Hearth.Communities.MemberJoined
  alias Hearth.Communities.OwnershipTransferred
  alias Hearth.Communities.Request
  alias Hearth.Communities.RequestDecided
  alias Hearth.Communities.Room
  alias Hearth.Events.Event
  alias Hearth.IAM
  alias Hearth.IAM.Membership
  alias Hearth.IAM.Role
  alias Hearth.TestUtils

  setup do
    :ok = Communities.subscribe_to_pubsub()

    owner = TestUtils.register_random_user!()
    community = TestUtils.create_random_community!(owner, template: "oss")

    {:ok, binding()}
  end

  describe "start_community/2" do
    test "fails if name is missing" do
      admin = TestUtils.register_random_user!(admin: true)

      assert {:error, changeset} = Communities.start_community(admin, %{name: " "})
      assert %{name: ["can't be blank"]} = errors_on(changeset)
    end

    test "fails if template is unknown" do
      admin = TestUtils.register_random_user!(admin: true)

      assert {:error, changeset} =
               Communities.start_community(admin, %{name: Company.name(), template: "nope"})

      assert %{template: ["is invalid"]} = errors_on(changeset)
    end

    test "start community as instance admin" do
      %{id: id} = admin = TestUtils.register_random_user!(admin: true)
      params = %{name: "Plant Parents", template: "club"}

      assert {:ok, %Community{} = community} = Communities.start_community(admin, params)
      assert community.owner_id == admin.id
      assert [%Room{slug: "general"} | _rooms] = community.rooms

      assert {:ok, %Membership{roles: [%{key: "owner"}]}} =
               IAM.get_membership(admin, community.id)

      assert_receive %CommunityCreated{owner_id: ^id, template: "club"}
    end
  end

  describe "slug_for/1" do
    test "numbers a taken name", %{owner: owner} do
      name = "Book club #{System.unique_integer([:positive])}"
      first = TestUtils.create_random_community!(owner, name: name)
      _second = TestUtils.create_random_community!(owner, name: name)

      assert Communities.slug_for(name) == first.slug <> "-3"
    end

    test "uses community for non latin names" do
      assert Communities.slug_for("读书会") == "community"
    end
  end

  describe "get_request/1" do
    test "returns not found if missing" do
      assert {:error, :not_found} = Communities.get_request(Common.new_id())
    end

    test "get request" do
      requester = TestUtils.register_random_user!()

      draft = %Request{requester_id: requester.id}
      {:ok, %{id: id}} = Request.insert(draft, %{name: Company.name()})

      assert {:ok, %Request{id: ^id}} = Communities.get_request(id)
    end
  end

  describe "decide_request/3" do
    setup do
      requester = TestUtils.register_random_user!()

      params = %{
        name: Company.name(),
        description: Lorem.paragraph(),
        template: "club",
        note: Lorem.sentence()
      }

      {:ok, request} = Request.insert(%Request{requester_id: requester.id}, params)

      {:ok, binding()}
    end

    test "fails if not an instance admin", %{owner: owner, request: request} do
      assert {:error, :forbidden} = Communities.decide_request(owner, request, :approved)
    end

    test "fails if already decided", %{request: request} do
      admin = TestUtils.register_random_user!(admin: true)
      {:ok, request} = Communities.decide_request(admin, request, :declined)

      assert {:error, :already_decided} = Communities.decide_request(admin, request, :approved)
    end

    test "decline request", %{request: %{id: id} = request} do
      admin = TestUtils.register_random_user!(admin: true)

      assert {:ok, %Request{status: :declined, community_id: nil}} =
               Communities.decide_request(admin, request, :declined)

      assert_receive %RequestDecided{request_id: ^id, status: :declined}
    end

    test "approve request", %{requester: %{id: requester_id} = requester, request: request} do
      admin = TestUtils.register_random_user!(admin: true)

      assert {:ok, %Request{status: :approved} = approved} =
               Communities.decide_request(admin, request, :approved)

      assert {:ok, community} = Communities.get_community(id: approved.community_id)
      assert community.owner_id == requester.id

      assert_receive %RequestDecided{status: :approved, requester_id: ^requester_id}
    end
  end

  describe "put_creation_mode/2" do
    test "fails if not an instance admin", %{owner: owner} do
      assert {:error, :forbidden} = Communities.put_creation_mode(owner, :anyone)
    end

    test "wins over the config" do
      TestUtils.put_community_creation("admins")
      admin = TestUtils.register_random_user!(admin: true)

      assert :ok = Communities.put_creation_mode(admin, :request)
      assert Communities.creation_mode() == :request
    end
  end

  describe "list_requests/2" do
    test "fails if not an instance admin", %{owner: owner} do
      assert {:error, :forbidden} = Communities.list_requests(owner, :pending)
    end
  end

  describe "list_public/0" do
    test "leaves out hidden and archived communities", %{community: community} do
      _invite = TestUtils.create_random_community!(nil, visibility: :invite_only)
      _private = TestUtils.create_random_community!(nil, visibility: :private)
      archived = TestUtils.create_random_community!(nil, visibility: :public)
      :ok = TestUtils.update_rows!(Community, [id: archived.id], archived_at: DateTime.utc_now())

      assert [listed] = Communities.list_public()
      assert listed.id == community.id
    end

    test "lists public communities with rooms" do
      opts = [visibility: :public_indexed]
      _birch = TestUtils.create_random_community!(nil, [name: "Birch Club"] ++ opts)
      alder = TestUtils.create_random_community!(nil, [name: "Alder Club"] ++ opts)

      assert [%{rooms: [_room | _rooms]} = first | _others] = Communities.list_public()
      assert first.id == alder.id
    end
  end

  describe "list_joined/1" do
    test "leaves out unjoined and archived" do
      owner = TestUtils.register_random_user!()
      _community = TestUtils.create_random_community!()
      community = TestUtils.create_random_community!(owner)
      :ok = TestUtils.update_rows!(Community, [id: community.id], archived_at: DateTime.utc_now())

      assert [] = Communities.list_joined(owner)
    end

    test "lists joined communities with rooms" do
      owner = TestUtils.register_random_user!()
      b_side = TestUtils.create_random_community!(owner, name: "B side")
      a_side = TestUtils.create_random_community!(owner, name: "A side")

      assert [%Community{rooms: [_room | _rooms]} | _others] =
               joined = Communities.list_joined(owner)

      assert TestUtils.pluck(joined, :id) == [a_side.id, b_side.id]
    end
  end

  describe "visible?/2" do
    test "hides private communities from people outside", %{owner: owner} do
      community = TestUtils.create_random_community!(owner, visibility: :private)

      refute Communities.visible?(community, nil)
      refute Communities.visible?(community, TestUtils.register_random_user!())
      assert Communities.visible?(community, owner)
    end

    test "shows invite only to signed in users", %{owner: owner} do
      community = TestUtils.create_random_community!(owner, visibility: :invite_only)

      refute Communities.visible?(community, nil)
      assert Communities.visible?(community, TestUtils.register_random_user!())
    end

    test "shows public communities to everyone", %{community: community} do
      assert Communities.visible?(community, nil)
    end
  end

  describe "readable?/2" do
    test "keeps invite only content from people outside", %{owner: owner} do
      community = TestUtils.create_random_community!(owner, visibility: :invite_only)

      refute Communities.readable?(community, nil)
      refute Communities.readable?(community, TestUtils.register_random_user!())
      assert Communities.readable?(community, owner)
    end

    test "keeps private content from people outside", %{owner: owner} do
      community = TestUtils.create_random_community!(owner, visibility: :private)

      refute Communities.readable?(community, TestUtils.register_random_user!())
      assert Communities.readable?(community, owner)
    end

    test "opens public content to everyone", %{community: community} do
      assert Communities.readable?(community, nil)
    end
  end

  describe "update_community/3" do
    test "fails without community.update", %{community: community} do
      member = TestUtils.join_random_member!(community)

      assert {:error, :forbidden} =
               Communities.update_community(member, community, %{name: Company.name()})
    end

    test "lets anyone with community.update change it", %{community: community} do
      editor = TestUtils.join_with_permissions!(community, ["community.update"])
      params = %{tagline: Lorem.sentence()}

      assert {:ok, updated} = Communities.update_community(editor, community, params)
      assert updated.tagline == params.tagline
    end

    test "keeps the slug", %{owner: owner, community: community} do
      params = %{name: Company.name()}

      assert {:ok, updated} = Communities.update_community(owner, community, params)
      assert updated.slug == community.slug
    end
  end

  describe "join/2" do
    test "fails if the community needs an invite", %{owner: owner} do
      community = TestUtils.create_random_community!(owner, visibility: :invite_only)

      assert {:error, :invite_required} =
               Communities.join(TestUtils.register_random_user!(), community)
    end

    test "fails if banned", %{owner: owner, community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _ban} = Communities.ban(owner, community, user, %{reason: Lorem.sentence()})

      assert {:error, :banned} = Communities.join(user, community)
    end

    test "join", %{community: community} do
      %{id: id} = user = TestUtils.register_random_user!()

      assert {:ok, %Membership{}} = Communities.join(user, community)
      assert_receive %MemberJoined{user_id: ^id}
    end
  end

  describe "leave/2" do
    test "fails if the owner", %{owner: owner, community: community} do
      assert {:error, :owner} = Communities.leave(owner, community)
    end

    test "leave", %{community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)

      assert :ok = Communities.leave(user, community)
      refute IAM.member?(user, community.id)
    end
  end

  describe "create_role/3" do
    test "fails for a member who may not change roles", %{community: community} do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert {:error, :forbidden} =
               Communities.create_role(member, community, %{key: "helpers", name: "Helpers"})
    end

    test "fails for a permission that doesn't exist", %{owner: owner, community: community} do
      assert {:error, changeset} =
               Communities.create_role(owner, community, %{
                 key: "helpers",
                 name: "Helpers",
                 permissions: ["everything.ever"]
               })

      assert %{permissions: [_message]} = errors_on(changeset)
    end

    test "fails for built in role", %{owner: owner, community: community} do
      assert {:ok, role} =
               Communities.create_role(owner, community, %{
                 key: "helpers",
                 name: "Helpers",
                 permissions: ["post.pin"],
                 is_system: true
               })

      assert %{key: "helpers", permissions: ["post.pin"], is_system: false} = role
    end
  end

  describe "update_role/3" do
    test "fails for the Owner role", %{owner: owner, community: community} do
      role = Role.get(community_id: community.id, key: "owner")

      assert {:error, :forbidden} = Communities.update_role(owner, role, %{name: "Boss"})
    end

    test "fails to change role key", %{owner: owner, community: community} do
      role = Role.get(community_id: community.id, key: "moderator")

      assert {:ok, %{name: "Stewards", key: "moderator"}} =
               Communities.update_role(owner, role, %{name: "Stewards", key: "stewards"})
    end
  end

  describe "delete_role/2" do
    test "fails for the Owner role", %{owner: owner, community: community} do
      role = Role.get(community_id: community.id, key: "owner")

      assert {:error, :system_role} = Communities.delete_role(owner, role)
    end

    test "deletes a role", %{owner: owner, community: community} do
      {:ok, role} = Communities.create_role(owner, community, %{key: "helpers", name: "Helpers"})

      assert {:ok, _role} = Communities.delete_role(owner, role)
      refute Role.exists?(community_id: community.id, key: "helpers")
    end
  end

  describe "set_member_roles/4" do
    test "fails to make anyone Owner", %{owner: owner, community: community} do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert {:error, :forbidden} =
               Communities.set_member_roles(owner, community, member, ["owner"])
    end

    test "fails to change the Owner's roles", %{owner: owner, community: community} do
      assert {:error, :forbidden} =
               Communities.set_member_roles(owner, community, owner, ["member"])
    end

    test "fails for someone who isn't a member", %{owner: owner, community: community} do
      assert {:error, :not_found} =
               Communities.set_member_roles(
                 owner,
                 community,
                 TestUtils.register_random_user!(),
                 ["moderator"]
               )
    end

    test "gives a member exactly the roles named", %{owner: owner, community: community} do
      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert {:ok, %Membership{roles: [%{key: "moderator"}]}} =
               Communities.set_member_roles(owner, community, member, ["moderator"])

      assert "content.remove" in IAM.permissions_for(member, community.id)
    end
  end

  describe "request_transfer_code/2" do
    test "fails if not the owner", %{community: community} do
      member = TestUtils.join_random_member!(community)

      assert {:error, :forbidden} = Communities.request_transfer_code(member, community)
    end

    test "request transfer code", %{owner: %{id: id, email: email} = owner, community: community} do
      :ok = Auth.subscribe_to_pubsub()
      name = community.name

      assert :ok = Communities.request_transfer_code(owner, community)

      assert_receive %TransferCodeRequested{
        user_id: ^id,
        email: ^email,
        community_name: ^name,
        ttl: 15
      }
    end
  end

  describe "transfer_ownership/4" do
    test "fails if not the owner", %{community: community} do
      user = TestUtils.join_random_member!(community)

      assert {:error, :forbidden} =
               Communities.transfer_ownership(user, community, user, "123456")
    end

    test "fails if the new owner is not a member", %{owner: owner, community: community} do
      code = TestUtils.transfer_code!(owner, community)
      outsider = TestUtils.register_random_user!()

      assert {:error, :not_a_member} =
               Communities.transfer_ownership(owner, community, outsider, code)
    end

    test "fails if code is wrong", %{owner: owner, community: community} do
      user = TestUtils.join_random_member!(community)

      assert {:error, :invalid} = Communities.transfer_ownership(owner, community, user, "000000")
    end

    test "fails with a code sent for another community", %{owner: owner, community: community} do
      other = TestUtils.create_random_community!(owner)
      code = TestUtils.transfer_code!(owner, other)
      user = TestUtils.join_random_member!(community)

      assert {:error, :invalid} = Communities.transfer_ownership(owner, community, user, code)
    end

    test "transfer ownership", %{owner: owner, community: community} do
      %{id: id} = user = TestUtils.join_random_member!(community)
      code = TestUtils.transfer_code!(owner, community)

      assert {:ok, %Community{} = transferred} =
               Communities.transfer_ownership(owner, community, user, code)

      assert transferred.owner_id == user.id

      assert {:ok, %Membership{roles: [%{key: "owner"}]}} = IAM.get_membership(user, community.id)

      assert {:ok, %Membership{roles: [%{key: "moderator"}]}} =
               IAM.get_membership(owner, community.id)

      assert_receive %OwnershipTransferred{to_id: ^id}
    end
  end

  describe "create_room/3" do
    test "fails if not allowed", %{community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)

      assert {:error, :forbidden} =
               Communities.create_room(user, community, %{name: Lorem.word()})
    end

    test "fails if name is taken", %{owner: owner, community: community} do
      assert {:error, changeset} = Communities.create_room(owner, community, %{name: "General"})
      assert %{name: ["has already been taken"]} = errors_on(changeset)
    end

    test "create room", %{owner: owner, community: community} do
      assert {:ok, %Room{slug: "release-notes", type: :text}} =
               Communities.create_room(owner, community, %{name: "Release notes"})
    end
  end

  describe "list_archived_rooms/2" do
    test "fails if not allowed", %{community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)

      assert {:error, :forbidden} = Communities.list_archived_rooms(user, community)
    end

    test "list archived rooms", %{owner: owner, community: community} do
      [room | _rooms] = Communities.list_rooms(community)
      {:ok, archived} = Communities.archive_room(owner, room)

      assert {:ok, [listed]} = Communities.list_archived_rooms(owner, community)
      assert listed.id == archived.id
    end
  end

  describe "archive_room/2" do
    test "fails if not allowed", %{community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)
      [room | _rooms] = Communities.list_rooms(community)

      assert {:error, :forbidden} = Communities.archive_room(user, room)
    end

    test "archive room", %{owner: owner, community: community} do
      [room | rooms] = Communities.list_rooms(community)

      assert {:ok, %Room{archived_at: %DateTime{}}} = Communities.archive_room(owner, room)
      assert Communities.list_rooms(community) == rooms
    end

    test "archive room as a moderator", %{community: community} do
      moderator = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(moderator, community.id, ["moderator"])
      [room | _rooms] = Communities.list_rooms(community)

      assert {:ok, %Room{archived_at: %DateTime{}}} = Communities.archive_room(moderator, room)
    end
  end

  describe "restore_room/2" do
    test "restore room", %{owner: owner, community: community} do
      [room | _rooms] = Communities.list_rooms(community)
      {:ok, archived} = Communities.archive_room(owner, room)

      assert {:ok, %Room{archived_at: nil}} = Communities.restore_room(owner, archived)
      assert [first | _rooms] = Communities.list_rooms(community)
      assert first.id == archived.id
    end
  end

  describe "delete_room/2" do
    test "fails for a moderator", %{community: community} do
      moderator = TestUtils.register_random_user!()
      {:ok, _membership} = IAM.join(moderator, community.id, ["moderator"])
      [room | _rooms] = Communities.list_rooms(community)

      assert {:error, :forbidden} = Communities.delete_room(moderator, room)
    end

    test "delete room with its events", %{owner: owner, community: community} do
      event = TestUtils.create_random_community_event!(owner, community)

      assert {:ok, %Room{id: id}} =
               Communities.delete_room(owner, TestUtils.get_room!(community, type: :voice))

      assert {:error, :not_found} = Communities.get_room(id: id)
      refute Event.exists?(id: event.id)
    end
  end

  describe "create_invite/3" do
    test "fails if role above default", %{community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)

      assert {:error, :forbidden} =
               Communities.create_invite(user, community, %{role_key: "moderator"})
    end

    test "create invite", %{owner: owner, community: community} do
      assert {:ok, %Invite{code: code, role_key: "moderator"}} =
               Communities.create_invite(owner, community, %{role_key: "moderator", max_uses: 5})

      assert String.length(code) == 10
    end
  end

  describe "accept_invite/2" do
    setup %{owner: owner} do
      community = TestUtils.create_random_community!(owner, visibility: :private)
      {:ok, invite} = Communities.create_invite(owner, community, %{max_uses: 1})

      {:ok, private: community, invite: invite}
    end

    test "fails if code is unknown" do
      assert {:error, :not_found} =
               Communities.accept_invite(TestUtils.register_random_user!(), "nope")
    end

    test "fails if revoked", %{owner: owner, invite: invite} do
      {:ok, _invite} = Communities.revoke_invite(owner, invite)

      assert {:error, :revoked} =
               Communities.accept_invite(TestUtils.register_random_user!(), invite.code)
    end

    test "fails if used up", %{invite: invite} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.accept_invite(user, invite.code)

      assert {:error, :used_up} =
               Communities.accept_invite(TestUtils.register_random_user!(), invite.code)
    end

    test "fails if expired", %{owner: owner, private: community} do
      {:ok, invite} = Communities.create_invite(owner, community, %{})

      :ok = TestUtils.update_rows!(Invite, [id: invite.id], expires_at: TestUtils.minutes_ago(1))

      assert {:error, :expired} =
               Communities.accept_invite(TestUtils.register_random_user!(), invite.code)
    end

    test "keeps membership without using invite", %{owner: owner, invite: invite} do
      assert {:ok, %Membership{}} = Communities.accept_invite(owner, invite.code)
      assert {:ok, %Invite{uses_count: 0}} = Communities.get_invite(invite.code)
    end

    test "accept invite", %{invite: invite} do
      user = TestUtils.register_random_user!()

      assert {:ok, %Membership{}} = Communities.accept_invite(user, invite.code)
      assert {:ok, %Invite{uses_count: 1}} = Communities.get_invite(invite.code)
    end
  end

  describe "email_invites/3" do
    test "fails if an address is invalid", %{owner: owner, community: community} do
      entries = [
        %{email: Internet.email(), role_key: "member"},
        %{email: "nope", role_key: "member"}
      ]

      assert {:error, changeset} = Communities.email_invites(owner, community, entries)
      assert %{email: ["is not a valid email"]} = errors_on(changeset)
      assert {:ok, %{emails: []}} = Communities.list_invites(owner, community)
    end

    test "fails if an address can't receive email", %{owner: owner, community: community} do
      entries = [%{email: "bo@typo.invalid", role_key: "member"}]

      assert {:error, changeset} = Communities.email_invites(owner, community, entries)
      assert %{email: ["can't receive email"]} = errors_on(changeset)
    end

    test "fails if role above default", %{community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)
      entries = [%{email: Internet.email(), role_key: "moderator"}]

      assert {:error, :forbidden} = Communities.email_invites(user, community, entries)
    end

    test "gives each person own code", %{owner: owner, community: community} do
      email = Internet.email()

      entries = [
        %{email: email, role_key: "moderator"},
        %{email: String.upcase(email), role_key: "member"}
      ]

      assert {:ok, [sent]} = Communities.email_invites(owner, community, entries)
      assert %Invite{max_uses: 1, role_key: "moderator", code: code} = sent.invite
      assert_receive %InvitesEmailed{invites: [%{email: ^email, code: ^code}]}
    end
  end

  describe "email_invites/4" do
    test "puts the inviter's note in the invite", %{owner: owner, community: community} do
      note = Lorem.sentence()
      entries = [%{email: Internet.email(), role_key: "member"}]

      assert {:ok, [_sent]} = Communities.email_invites(owner, community, entries, note)
      assert_receive %InvitesEmailed{note: ^note}
    end
  end

  describe "list_invites/2" do
    test "fails if not allowed to invite", %{community: community} do
      assert {:error, :forbidden} =
               Communities.list_invites(TestUtils.register_random_user!(), community)
    end

    test "hides emailed people from members", %{owner: owner, community: community} do
      {:ok, link} = Communities.create_invite(owner, community, %{})

      entries = [%{email: Internet.email(), role_key: "member"}]
      {:ok, _sent} = Communities.email_invites(owner, community, entries)

      member = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(member, community)

      assert {:ok, %{links: [listed], emails: []}} = Communities.list_invites(member, community)
      assert listed.id == link.id
    end

    test "keeps links and emailed invites apart", %{owner: owner, community: community} do
      {:ok, link} = Communities.create_invite(owner, community, %{})
      email = Internet.email()

      entries = [%{email: email, role_key: "member"}]
      {:ok, _sent} = Communities.email_invites(owner, community, entries)

      assert {:ok, %{links: [listed], emails: [emailed]}} =
               Communities.list_invites(owner, community)

      assert listed.id == link.id
      assert emailed.email == email
    end
  end

  describe "update_invite/3" do
    test "fails if new role above default", %{
      owner: owner,
      community: community
    } do
      {:ok, invite} = Communities.create_invite(owner, community, %{})

      {:ok, _membership} =
        Communities.accept_invite(TestUtils.register_random_user!(), invite.code)

      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)

      assert {:error, :forbidden} =
               Communities.update_invite(user, invite, %{role_key: "moderator"})
    end

    test "update invite", %{owner: owner, community: community} do
      {:ok, invite} = Communities.create_invite(owner, community, %{})

      assert {:ok, %Invite{max_uses: 10, expires_at: nil}} =
               Communities.update_invite(owner, invite, %{max_uses: 10, expires_at: nil})
    end
  end

  describe "list_my_invites/1" do
    test "leaves out invites answered or revoked", %{owner: owner, community: community} do
      user = TestUtils.register_random_user!()
      entries = [%{email: user.email, role_key: "member"}]
      {:ok, [sent]} = Communities.email_invites(owner, community, entries)
      {:ok, _revoked} = Communities.revoke_email_invite(owner, sent)

      assert [] = Communities.list_my_invites(user)
    end

    test "lists the invites waiting for an answer", %{owner: owner, community: community} do
      user = TestUtils.register_random_user!()

      entries = [%{email: user.email, role_key: "member"}]
      {:ok, [sent]} = Communities.email_invites(owner, community, entries)

      assert [%{id: id, invite: %Invite{community: %Community{}}}] =
               Communities.list_my_invites(user)

      assert id == sent.id
    end

    test "finds invite with different email case", %{
      owner: owner,
      community: community
    } do
      user = TestUtils.register_random_user!()
      entries = [%{email: String.upcase(user.email), role_key: "member"}]
      {:ok, [sent]} = Communities.email_invites(owner, community, entries)

      refute TestUtils.stored_value!(InviteEmail, sent.id, :email) =~ user.email
      assert [%{id: id}] = Communities.list_my_invites(user)
      assert id == sent.id
    end
  end

  describe "decline_email_invite/2" do
    test "fails for an invite sent to someone else", %{owner: owner, community: community} do
      entries = [%{email: Internet.email(), role_key: "member"}]
      {:ok, [sent]} = Communities.email_invites(owner, community, entries)

      assert {:error, :not_found} =
               Communities.decline_email_invite(TestUtils.register_random_user!(), sent)
    end

    test "turns the invite down and stops its code", %{owner: owner, community: community} do
      user = TestUtils.register_random_user!()

      entries = [%{email: user.email, role_key: "member"}]
      {:ok, [sent]} = Communities.email_invites(owner, community, entries)

      assert {:ok, %{status: :declined}} = Communities.decline_email_invite(user, sent)
      assert {:error, :revoked} = Communities.accept_invite(user, sent.invite.code)
    end
  end

  describe "revoke_email_invite/2" do
    test "fails if not allowed to invite", %{owner: owner, community: community} do
      entries = [%{email: Internet.email(), role_key: "member"}]
      {:ok, [sent]} = Communities.email_invites(owner, community, entries)

      assert {:error, :forbidden} =
               Communities.revoke_email_invite(TestUtils.register_random_user!(), sent)
    end

    test "stops only that person's code", %{owner: owner, community: community} do
      entries = [
        %{email: Internet.email(), role_key: "member"},
        %{email: Internet.email(), role_key: "member"}
      ]

      {:ok, [revoked, kept]} = Communities.email_invites(owner, community, entries)

      assert {:ok, %{status: :revoked}} = Communities.revoke_email_invite(owner, revoked)

      assert {:error, :revoked} =
               Communities.accept_invite(TestUtils.register_random_user!(), revoked.invite.code)

      assert {:ok, _membership} =
               Communities.accept_invite(TestUtils.register_random_user!(), kept.invite.code)
    end
  end

  describe "ban/4" do
    test "fails if not allowed", %{community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)

      assert {:error, :forbidden} =
               Communities.ban(user, community, TestUtils.register_random_user!(), %{})
    end

    test "fails if banning the owner or oneself", %{owner: owner, community: community} do
      assert {:error, :forbidden} = Communities.ban(owner, community, owner, %{})
    end

    test "fails if already banned", %{owner: owner, community: community} do
      user = TestUtils.register_random_user!()
      {:ok, _ban} = Communities.ban(owner, community, user, %{})

      assert {:error, changeset} = Communities.ban(owner, community, user, %{})
      assert %{user_id: ["is already banned"]} = errors_on(changeset)
    end

    test "ban", %{owner: owner, community: community} do
      %{id: id} = user = TestUtils.register_random_user!()
      {:ok, _membership} = Communities.join(user, community)

      assert {:ok, %Ban{}} = Communities.ban(owner, community, user, %{reason: Lorem.sentence()})
      refute IAM.member?(user, community.id)
      assert Communities.banned?(user, community)
      assert_receive %MemberBanned{user_id: ^id}
    end
  end

  describe "lift_ban/2" do
    test "lift ban", %{owner: owner, community: community} do
      user = TestUtils.register_random_user!()
      {:ok, ban} = Communities.ban(owner, community, user, %{})

      assert {:ok, %Ban{lifted_at: %DateTime{}}} = Communities.lift_ban(owner, ban)
      refute Communities.banned?(user, community)
    end
  end
end
