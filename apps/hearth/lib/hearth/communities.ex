defmodule Hearth.Communities do
  events = [
    CommunityCreated,
    InvitesEmailed,
    MemberBanned,
    MemberJoined,
    MemberLeft,
    OwnershipTransferred,
    RequestDecided,
    RoomChanged
  ]

  default = [Ban, Community, Invite, Request, Room | events]

  exports =
    case Mix.env() do
      :test -> default ++ [Category, InviteEmail]
      _env -> default
    end

  use Boundary,
    deps: [
      Hearth.Accounts,
      Hearth.Auth,
      Hearth.Common,
      Hearth.IAM,
      Hearth.PubSub,
      Hearth.Repo,
      Hearth.Vault
    ],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Auth
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Communities.Ban
  alias Hearth.Communities.Command.ApproveRequest
  alias Hearth.Communities.Command.BanMember
  alias Hearth.Communities.Command.CreateCommunity
  alias Hearth.Communities.Command.EmailInvite
  alias Hearth.Communities.Command.RevokeEmailInvite
  alias Hearth.Communities.Command.TransferOwnership
  alias Hearth.Communities.Community
  alias Hearth.Communities.CommunityCreated
  alias Hearth.Communities.InstanceSettings
  alias Hearth.Communities.Invite
  alias Hearth.Communities.InviteEmail
  alias Hearth.Communities.InvitesEmailed
  alias Hearth.Communities.MemberBanned
  alias Hearth.Communities.MemberJoined
  alias Hearth.Communities.MemberLeft
  alias Hearth.Communities.OwnershipTransferred
  alias Hearth.Communities.Request
  alias Hearth.Communities.RequestDecided
  alias Hearth.Communities.Room
  alias Hearth.Communities.RoomChanged
  alias Hearth.Communities.Template
  alias Hearth.IAM
  alias Hearth.IAM.Membership
  alias Hearth.IAM.Role
  alias Hearth.PubSub

  @moderation_ranks %{none: 0, reports: 1, full: 2}

  @topic "communities"
  @open [:public_indexed, :public]
  @levels ~w[full reports none]a

  @owner_role "owner"
  @role_fields ~w[name color position permissions]a
  @new_role_fields [:key | @role_fields]
  @owned_limit 3
  @account_age_hours 24

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec template_ids() :: [String.t()]
  def template_ids, do: Template.ids()

  @spec list_templates() :: [Template.t()]
  def list_templates, do: Template.all()

  @spec creation_mode() :: :admins | :request | :anyone
  def creation_mode do
    case InstanceSettings.get(id: 1) do
      %InstanceSettings{creation: mode} -> mode
      nil -> configured_creation_mode()
    end
  end

  @spec put_creation_mode(User.t(), atom()) ::
          :ok | {:error, :forbidden | Changeset.t()}
  def put_creation_mode(%User{is_instance_admin: true}, mode) do
    with {:ok, _settings} <- InstanceSettings.put_creation(mode), do: :ok
  end

  def put_creation_mode(%User{}, _mode), do: {:error, :forbidden}

  defp configured_creation_mode do
    case Application.fetch_env!(:hearth, __MODULE__)[:creation] do
      "request" -> :request
      "anyone" -> :anyone
      _admins -> :admins
    end
  end

  @spec start_community(User.t(), map()) ::
          {:ok, Community.t()}
          | {:requested, Request.t()}
          | {:error,
             :forbidden | :unconfirmed_email | :account_too_new | :too_many_owned | Changeset.t()}
  def start_community(%User{is_instance_admin: true} = user, params), do: create(user, params)

  def start_community(%User{} = user, %{} = params) do
    case creation_mode() do
      :admins -> {:error, :forbidden}
      :request -> request_community(user, params)
      :anyone -> with :ok <- may_start?(user), do: create(user, params)
    end
  end

  @spec list_requests(User.t(), :pending | :approved | :declined) ::
          {:ok, [Request.t()]} | {:error, :forbidden}
  def list_requests(%User{} = user, status) do
    case IAM.can?(user, :decide, :"community.request") do
      true ->
        {:ok, Request.list(status)}

      false ->
        {:error, :forbidden}
    end
  end

  @spec get_request(Common.T.id()) :: {:ok, Request.t()} | {:error, :not_found}
  def get_request(id) when is_binary(id) do
    case Request.get(id: id, preload: :community) do
      nil -> {:error, :not_found}
      %Request{} = request -> {:ok, request}
    end
  end

  @spec decide_request(User.t(), Request.t(), :approved | :declined) ::
          {:ok, Request.t()} | {:error, :forbidden | :already_decided | Changeset.t()}
  def decide_request(%User{} = admin, %Request{} = request, decision)
      when decision in [:approved, :declined] do
    with true <- IAM.can?(admin, :decide, :"community.request"),
         :pending <- request.status,
         {:ok, request} <- decide(admin, request, decision) do
      broadcast(%RequestDecided{
        request_id: request.id,
        requester_id: request.requester_id,
        status: request.status,
        community_id: request.community_id
      })

      {:ok, request}
    else
      false -> {:error, :forbidden}
      status when is_atom(status) -> {:error, :already_decided}
      {:error, _reason} = error -> error
    end
  end

  @spec slug_for(String.t()) :: Common.T.slug()
  def slug_for(name) when is_binary(name), do: Community.free_slug(name)

  @spec readable_ids(nil | User.t()) :: [Common.T.id()]
  def readable_ids(nil), do: Community.readable_ids([])

  def readable_ids(%User{} = reader),
    do: reader |> IAM.community_ids() |> Community.readable_ids()

  @spec list_public() :: [Community.t()]
  def list_public, do: Community.public()

  @spec list_indexed() :: [Community.t()]
  def list_indexed, do: Community.indexed()

  @spec list_joined(User.t()) :: [Community.t()]
  def list_joined(%User{} = user) do
    user
    |> IAM.community_ids()
    |> Community.joined()
  end

  @spec get_community(keyword()) :: {:ok, Community.t()} | {:error, :not_found}
  def get_community(opts) when is_list(opts) do
    case Community.get(opts) do
      nil -> {:error, :not_found}
      %Community{} = community -> {:ok, community}
    end
  end

  @spec visible?(Community.t(), nil | User.t()) :: boolean()
  def visible?(%Community{visibility: visibility}, _viewer) when visibility in @open, do: true
  def visible?(%Community{visibility: :invite_only}, %User{}), do: true
  def visible?(%Community{} = community, %User{} = user), do: IAM.member?(user, community.id)
  def visible?(%Community{}, nil), do: false

  # Someone who may not know a community exists hears that what is inside it doesn't exist either
  @spec refusal(nil | User.t(), Common.T.id()) :: {:error, :forbidden | :not_found}
  def refusal(user, community_id) when is_binary(community_id) do
    with {:ok, community} <- get_community(id: community_id),
         true <- visible?(community, user) do
      {:error, :forbidden}
    else
      _hidden -> {:error, :not_found}
    end
  end

  @spec readable?(Community.t(), nil | User.t()) :: boolean()
  def readable?(%Community{visibility: visibility}, _viewer) when visibility in @open, do: true
  def readable?(%Community{} = community, %User{} = user), do: IAM.member?(user, community.id)
  def readable?(%Community{}, nil), do: false

  @spec update_community(User.t(), Community.t(), map()) ::
          {:ok, Community.t()} | {:error, :forbidden | Changeset.t()}
  def update_community(%User{} = user, %Community{} = community, %{} = params) do
    with :ok <- authorize(user, :update, :community, community),
         do: Community.update(community, params)
  end

  @spec join(User.t(), Community.t()) ::
          {:ok, IAM.Membership.t()} | {:error, :invite_required | :banned | Changeset.t()}
  def join(%User{} = user, %Community{visibility: visibility} = community)
      when visibility in @open do
    add_member(user, community, [])
  end

  def join(%User{}, %Community{}), do: {:error, :invite_required}

  @spec leave(User.t(), Community.t()) :: :ok | {:error, :owner}
  def leave(%User{id: id}, %Community{owner_id: id}), do: {:error, :owner}

  def leave(%User{} = user, %Community{} = community) do
    :ok = IAM.leave(user, community.id)
    broadcast(%MemberLeft{community_id: community.id, user_id: user.id})
  end

  @spec create_role(User.t(), Community.t(), map()) ::
          {:ok, Role.t()} | {:error, :forbidden | Changeset.t()}
  def create_role(%User{} = user, %Community{} = community, %{} = params) do
    with :ok <- authorize(user, :update, :role, community) do
      IAM.create_role(community.id, Map.take(params, @new_role_fields))
    end
  end

  # The Owner role always holds every permission so it can't be changed
  @spec update_role(User.t(), Role.t(), map()) ::
          {:ok, Role.t()} | {:error, :forbidden | Changeset.t()}
  def update_role(%User{}, %Role{key: @owner_role}, %{}), do: {:error, :forbidden}

  def update_role(%User{} = user, %Role{} = role, %{} = params) do
    with :ok <- authorize(user, :update, :role, role) do
      IAM.update_role(role, Map.take(params, @role_fields))
    end
  end

  @spec delete_role(User.t(), Role.t()) ::
          {:ok, Role.t()} | {:error, :forbidden | :system_role | :default_role}
  def delete_role(%User{} = user, %Role{} = role) do
    with :ok <- authorize(user, :update, :role, role), do: IAM.delete_role(role)
  end

  # Ownership moves only through transfer_ownership/3
  @spec set_member_roles(User.t(), Community.t(), User.t(), [String.t()]) ::
          {:ok, Membership.t()} | {:error, :forbidden | :not_found | Changeset.t()}
  def set_member_roles(%User{} = user, %Community{} = community, %User{} = member, keys)
      when is_list(keys) do
    with :ok <- authorize(user, :update, :role, community),
         true <- @owner_role not in keys and member.id != community.owner_id,
         {:ok, membership} <- IAM.get_membership(member, community.id) do
      IAM.set_roles(membership, keys)
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  @spec get_role(T.id()) :: {:ok, Role.t()} | {:error, :not_found}
  def get_role(id) when is_binary(id), do: IAM.get_role(id)

  # Only the Owner can hand a community over and they confirm it with a code sent to their email
  @spec request_transfer_code(User.t(), Community.t()) ::
          :ok | {:error, :forbidden | Changeset.t()}
  def request_transfer_code(%User{id: id} = owner, %Community{owner_id: id} = community),
    do: Auth.request_transfer_code(owner, community)

  def request_transfer_code(%User{}, %Community{}), do: {:error, :forbidden}

  @spec transfer_ownership(User.t(), Community.t(), User.t(), String.t()) ::
          {:ok, Community.t()}
          | {:error, :forbidden | :not_a_member | :invalid | :expired | Changeset.t()}
  def transfer_ownership(
        %User{id: id} = owner,
        %Community{owner_id: id} = community,
        %User{} = to,
        code
      ) do
    with true <- IAM.member?(to, community.id),
         :ok <- Auth.use_transfer_code(owner, community.id, code),
         {:ok, community} <- TransferOwnership.execute(owner, community, to) do
      broadcast(%OwnershipTransferred{community_id: community.id, from_id: id, to_id: to.id})
      {:ok, community}
    else
      false -> {:error, :not_a_member}
      {:error, :not_found} -> {:error, :not_a_member}
      {:error, _reason} = error -> error
    end
  end

  def transfer_ownership(%User{}, %Community{}, %User{}, _code), do: {:error, :forbidden}

  @spec list_rooms(Community.t()) :: [Room.t()]
  def list_rooms(%Community{id: id}), do: Room.for_community(id)

  @spec list_rooms([T.id()], :text | :voice) :: [Room.t()]
  def list_rooms(community_ids, type) when is_list(community_ids) and type in [:text, :voice],
    do: Room.all(community_id: community_ids, type: type, archived_at: nil)

  @spec moderation_level(Community.t(), nil | Room.t()) :: :full | :reports | :none
  def moderation_level(%Community{moderation: level}, nil), do: level
  def moderation_level(%Community{moderation: level}, %Room{moderation: nil}), do: level

  def moderation_level(%Community{moderation: community}, %Room{moderation: room}),
    do: Enum.min_by([community, room], &@moderation_ranks[&1])

  @spec get_room(keyword()) :: {:ok, Room.t()} | {:error, :not_found}
  def get_room(opts) when is_list(opts) do
    case Room.get(opts) do
      nil -> {:error, :not_found}
      %Room{} = room -> {:ok, room}
    end
  end

  @spec create_room(User.t(), Community.t(), map()) ::
          {:ok, Room.t()} | {:error, :forbidden | Changeset.t()}
  def create_room(%User{} = user, %Community{} = community, %{} = params) do
    with :ok <- authorize(user, :update, :room, community),
         {:ok, room} <- Room.insert(%Room{community_id: community.id}, params) do
      broadcast(%RoomChanged{community_id: community.id, room_id: room.id})
      {:ok, room}
    end
  end

  @spec update_room(User.t(), Room.t(), map()) ::
          {:ok, Room.t()} | {:error, :forbidden | Changeset.t()}
  def update_room(%User{} = user, %Room{} = room, %{} = params) do
    with :ok <- authorize(user, :update, :room, room),
         {:ok, room} <- Room.update(room, params) do
      broadcast(%RoomChanged{community_id: room.community_id, room_id: room.id})
      {:ok, room}
    end
  end

  # No checks here since only Hearth.Moderation.set_level/3 calls this
  @spec put_moderation(Community.t() | Room.t(), nil | Community.level()) ::
          {:ok, Community.t() | Room.t()} | {:error, Changeset.t()}
  def put_moderation(%Community{} = community, level) when level in @levels do
    Community.put_moderation(community, level)
  end

  def put_moderation(%Room{} = room, level) when is_nil(level) or level in @levels do
    with {:ok, room} <- Room.put_moderation(room, level) do
      broadcast(%RoomChanged{community_id: room.community_id, room_id: room.id})
      {:ok, room}
    end
  end

  @spec list_bans(Community.t()) :: [Ban.t()]
  def list_bans(%Community{id: id}), do: Ban.in_force(id)

  @spec get_ban(Common.T.id()) :: {:ok, Ban.t()} | {:error, :not_found}
  def get_ban(id) when is_binary(id) do
    case Ban.get(id: id) do
      nil -> {:error, :not_found}
      %Ban{} = ban -> {:ok, ban}
    end
  end

  @spec list_archived_rooms(User.t(), Community.t()) :: {:ok, [Room.t()]} | {:error, :forbidden}
  def list_archived_rooms(%User{} = user, %Community{} = community) do
    with :ok <- authorize(user, :update, :room, community) do
      {:ok, Room.archived(community.id)}
    end
  end

  @spec archive_room(User.t(), Room.t()) :: {:ok, Room.t()} | {:error, :forbidden | Changeset.t()}
  def archive_room(%User{} = user, %Room{} = room) do
    with :ok <- authorize(user, :update, :room, room),
         {:ok, room} <- Room.archive(room) do
      broadcast(%RoomChanged{community_id: room.community_id, room_id: room.id})
      {:ok, room}
    end
  end

  @spec restore_room(User.t(), Room.t()) :: {:ok, Room.t()} | {:error, :forbidden | Changeset.t()}
  def restore_room(%User{} = user, %Room{} = room) do
    with :ok <- authorize(user, :update, :room, room),
         {:ok, room} <- Room.restore(room) do
      broadcast(%RoomChanged{community_id: room.community_id, room_id: room.id})
      {:ok, room}
    end
  end

  @spec delete_room(User.t(), Room.t()) :: {:ok, Room.t()} | {:error, :forbidden | Changeset.t()}
  def delete_room(%User{} = user, %Room{} = room) do
    with :ok <- authorize(user, :delete, :room, room),
         {:ok, room} <- Room.delete(room) do
      broadcast(%RoomChanged{community_id: room.community_id, room_id: room.id})
      {:ok, room}
    end
  end

  # A role other than the default needs role.update so an invite can't hand out more than its maker has
  @spec create_invite(User.t(), Community.t(), map()) ::
          {:ok, Invite.t()} | {:error, :forbidden | Changeset.t()}
  def create_invite(%User{} = user, %Community{} = community, %{} = params) do
    role_key = params[:role_key] || params["role_key"] || "member"

    with :ok <- authorize(user, :create, :invite, community),
         :ok <- may_grant?(user, community, role_key) do
      invite = %Invite{community_id: community.id, created_by_id: user.id}
      params = Map.new(params, fn {key, value} -> {to_string(key), value} end)

      Invite.insert(invite, Map.put(params, "role_key", role_key))
    end
  end

  @spec revoke_invite(User.t(), Invite.t()) ::
          {:ok, Invite.t()} | {:error, :forbidden | Changeset.t()}
  def revoke_invite(%User{} = user, %Invite{} = invite) do
    with :ok <- authorize(user, :update, :invite, invite), do: Invite.revoke(invite)
  end

  @spec get_invite(String.t()) :: {:ok, Invite.t()} | {:error, :not_found}
  def get_invite(code) when is_binary(code) do
    case Invite.get(code: code, preload: :community) do
      nil -> {:error, :not_found}
      %Invite{} = invite -> {:ok, invite}
    end
  end

  @spec invite_usable?(Invite.t()) :: boolean()
  def invite_usable?(%Invite{} = invite), do: Invite.unusable(invite) == nil

  @spec accept_invite(User.t(), String.t()) ::
          {:ok, IAM.Membership.t()}
          | {:error, :not_found | :revoked | :expired | :used_up | :banned | Changeset.t()}
  def accept_invite(%User{} = user, code) when is_binary(code) do
    with {:ok, invite} <- get_invite(code),
         {:error, :not_found} <- IAM.get_membership(user, invite.community_id),
         nil <- Invite.unusable(invite),
         {:ok, membership} <- add_member(user, invite.community, [invite.role_key]) do
      count_use(invite, user)
      {:ok, membership}
    else
      {:ok, %IAM.Membership{} = membership} -> {:ok, membership}
      reason when is_atom(reason) -> {:error, reason}
      {:error, _reason} = error -> error
    end
  end

  @spec email_invites(
          User.t(),
          Community.t(),
          [%{email: String.t(), role_key: String.t()}],
          nil | String.t()
        ) :: {:ok, [InviteEmail.t()]} | {:error, :forbidden | Changeset.t()}
  def email_invites(%User{} = user, %Community{} = community, entries, note \\ nil)
      when is_list(entries) do
    roles = entries |> Enum.map(& &1.role_key) |> Enum.uniq()

    with :ok <- authorize(user, :update, :invite, community),
         :ok <- Enum.reduce_while(roles, :ok, &grant_or_halt(user, community, &1, &2)),
         {:ok, sent} <- EmailInvite.execute(user, community, entries) do
      broadcast(%InvitesEmailed{
        community_id: community.id,
        community_name: community.name,
        inviter_id: user.id,
        inviter_name: user.display_name || user.username,
        note: note,
        invites: Enum.map(sent, &%{email: &1.email, code: &1.invite.code})
      })

      {:ok, sent}
    end
  end

  @spec list_invites(User.t(), Community.t()) ::
          {:ok, %{links: [Invite.t()], emails: [InviteEmail.t()]}} | {:error, :forbidden}
  def list_invites(%User{} = user, %Community{} = community) do
    with :ok <- authorize(user, :create, :invite, community) do
      emails =
        case authorize(user, :update, :invite, community) do
          :ok -> InviteEmail.for_community(community.id)
          {:error, :forbidden} -> []
        end

      {:ok, %{links: Invite.links(community.id), emails: emails}}
    end
  end

  @spec update_invite(User.t(), Invite.t(), map()) ::
          {:ok, Invite.t()} | {:error, :forbidden | Changeset.t()}
  def update_invite(%User{} = user, %Invite{} = invite, %{} = params) do
    role_key = params[:role_key] || params["role_key"] || invite.role_key

    with :ok <- authorize(user, :update, :invite, invite),
         :ok <- may_grant?(user, %Community{id: invite.community_id}, role_key) do
      Invite.update(invite, params)
    end
  end

  @spec get_invite_email(T.id()) :: {:ok, InviteEmail.t()} | {:error, :not_found}
  def get_invite_email(id) when is_binary(id) do
    case InviteEmail.get(id: id, preload: :invite) do
      nil -> {:error, :not_found}
      %InviteEmail{} = invite_email -> {:ok, invite_email}
    end
  end

  @spec list_my_invites(User.t()) :: [InviteEmail.t()]
  def list_my_invites(%User{email: email}) do
    email
    |> InviteEmail.pending_for()
    |> Enum.filter(&invite_usable?(&1.invite))
  end

  @spec decline_email_invite(User.t(), InviteEmail.t()) ::
          {:ok, InviteEmail.t()} | {:error, :not_found | Changeset.t()}
  def decline_email_invite(%User{email: email}, %InviteEmail{email: email} = invite_email),
    do: RevokeEmailInvite.execute(invite_email, :declined)

  def decline_email_invite(%User{}, %InviteEmail{}), do: {:error, :not_found}

  @spec revoke_email_invite(User.t(), InviteEmail.t()) ::
          {:ok, InviteEmail.t()} | {:error, :forbidden | Changeset.t()}
  def revoke_email_invite(%User{} = user, %InviteEmail{invite: %Invite{} = invite} = invite_email) do
    with :ok <- authorize(user, :update, :invite, invite),
         do: RevokeEmailInvite.execute(invite_email)
  end

  @spec ban(User.t(), Community.t(), User.t(), map()) ::
          {:ok, Ban.t()} | {:error, :forbidden | Changeset.t()}
  def ban(%User{} = moderator, %Community{} = community, %User{} = target, %{} = params) do
    with :ok <- authorize(moderator, :ban, :member, community),
         true <- target.id not in [moderator.id, community.owner_id],
         {:ok, ban} <- BanMember.execute(moderator, community, target, params) do
      broadcast(%MemberBanned{
        community_id: community.id,
        user_id: target.id,
        banned_by_id: moderator.id
      })

      {:ok, ban}
    else
      false -> {:error, :forbidden}
      error -> error
    end
  end

  @spec lift_ban(User.t(), Ban.t()) :: {:ok, Ban.t()} | {:error, :forbidden | Changeset.t()}
  def lift_ban(%User{} = moderator, %Ban{} = ban) do
    with :ok <- authorize(moderator, :ban, :member, ban), do: Ban.lift(ban, moderator.id)
  end

  @spec banned?(User.t(), Community.t() | Common.T.id()) :: boolean()
  def banned?(%User{} = user, %Community{id: id}), do: banned?(user, id)

  def banned?(%User{id: user_id}, community_id) when is_binary(community_id) do
    Ban.active?(community_id, user_id)
  end

  defp create(user, params) do
    with {:ok, community} <- CreateCommunity.execute(user, params) do
      broadcast(%CommunityCreated{
        community_id: community.id,
        owner_id: user.id,
        template: community.template
      })

      {:ok, community}
    end
  end

  defp request_community(user, params) do
    with {:ok, request} <- Request.insert(%Request{requester_id: user.id}, params) do
      {:requested, request}
    end
  end

  defp decide(admin, request, :declined), do: Request.decline(request, admin.id)
  defp decide(admin, request, :approved), do: ApproveRequest.execute(admin, request)

  defp may_start?(%User{} = user) do
    owned = Community.owned_count(user.id)

    age_hours = DateTime.diff(DateTime.utc_now(), user.inserted_at, :hour)

    cond do
      is_nil(user.email_confirmed_at) -> {:error, :unconfirmed_email}
      age_hours < @account_age_hours -> {:error, :account_too_new}
      owned >= @owned_limit -> {:error, :too_many_owned}
      true -> :ok
    end
  end

  defp grant_or_halt(user, community, role_key, :ok) do
    case may_grant?(user, community, role_key) do
      :ok -> {:cont, :ok}
      error -> {:halt, error}
    end
  end

  defp may_grant?(user, community, role_key) do
    default? =
      community.id
      |> IAM.list_roles()
      |> Enum.any?(&(&1.key == role_key and &1.is_default))

    case default? or IAM.can?(user, :update, %{type: :role, community_id: community.id}) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp add_member(user, community, keys) do
    case banned?(user, community) do
      true -> {:error, :banned}
      false -> insert_member(user, community, keys)
    end
  end

  defp insert_member(user, community, keys) do
    with {:ok, membership} <- IAM.join(user, community.id, keys) do
      broadcast(%MemberJoined{community_id: community.id, user_id: user.id})
      {:ok, membership}
    end
  end

  defp count_use(invite, user) do
    :ok = Invite.count_use(invite)
    InviteEmail.accept(invite.id, user.email)
  end

  defp authorize(user, action, type, %{community_id: community_id}) do
    authorize(user, action, type, %Community{id: community_id})
  end

  defp authorize(user, action, type, %Community{id: id}) do
    case IAM.can?(user, action, %{type: type, community_id: id}) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp broadcast(event), do: PubSub.broadcast(@topic, event)
end
