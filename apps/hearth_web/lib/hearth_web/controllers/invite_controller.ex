defmodule HearthWeb.InviteController do
  use HearthWeb, :api_controller
  use Request.Validator.Plug

  import Request.Validator, only: [sigil_V: 2]
  import Request.Validator.Rules
  import HearthWeb.Rules

  alias Hearth.Accounts
  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.IAM
  alias HearthWeb.Avatars
  alias HearthWeb.CommunityExtras
  alias Plug.Conn

  tags ["Communities"]

  @code [in: :path, schema: %{type: :string, minLength: 1, maxLength: 64}]
  @community_id [in: :path, schema: %{type: :string, format: :uuid}]

  operation :index,
    summary: "List a community's invites",
    description: "Needs invite.create",
    security: [%{"bearer" => []}],
    parameters: [community_id: @community_id],
    responses: [
      ok: {Schema.InviteList, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"community_id" => ~V[required|uuid]}

  def index(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => community_id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, invites} <- Communities.list_invites(auth, community) do
      render(conn, :index, invites)
    end
  end

  operation :create,
    summary: "Make an invite link",
    description: "Needs role.update to invite with a role other than the default",
    security: [%{"bearer" => []}],
    parameters: [community_id: @community_id],
    request_body: {Schema.CreateInviteBody, required: false},
    responses: [
      created: {Schema.Invite, description: "Created"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "role_key" => ~V[string|min:1|max:40],
    "max_uses" => ~V[integer|min:1|max:10000],
    "expires_at" => ~V[string]
  }

  def create(%Conn{assigns: %{auth: %{}}} = conn, %{"community_id" => community_id} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    attrs = params |> Map.take(~w[role_key max_uses expires_at]) |> Common.atomize_string_keys()

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, invite} <- Communities.create_invite(auth, community, attrs) do
      conn |> put_status(:created) |> render(:create, invite: invite)
    end
  end

  operation :show,
    summary: "Show what an invite is for",
    description: "Needs no sign in",
    parameters: [code: @code],
    responses: [
      ok: {Schema.InvitePreview, description: "OK"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"code" => ~V[required|string|min:1|max:64]}

  def show(conn, %{"code" => code}) do
    with {:ok, invite} <- Communities.get_invite(code) do
      inviter =
        [invite.created_by_id] |> Accounts.list_users() |> Avatars.put_urls() |> List.first()

      role_name =
        invite.community_id
        |> IAM.list_roles()
        |> Enum.find_value(invite.role_key, fn role ->
          if role.key == invite.role_key, do: role.name
        end)

      render(conn, :show,
        invite: invite,
        usable: Communities.invite_usable?(invite),
        inviter: inviter,
        role_name: role_name,
        community: CommunityExtras.put_one(invite.community, nil)
      )
    end
  end

  operation :update,
    summary: "Change an invite link",
    security: [%{"bearer" => []}],
    parameters: [code: @code],
    request_body: Schema.CreateInviteBody,
    responses: [
      ok: {Schema.Invite, description: "OK"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "code" => ~V[required|string|min:1|max:64],
    "role_key" => ~V[string|min:1|max:40],
    "max_uses" => ~V[integer|min:1|max:10000],
    "expires_at" => ~V[string]
  }

  def update(%Conn{assigns: %{auth: %{}}} = conn, %{"code" => code} = params) do
    %Conn{assigns: %{auth: auth}} = conn

    changes = params |> Map.take(~w[role_key max_uses expires_at]) |> Common.atomize_string_keys()

    with {:ok, invite} <- Communities.get_invite(code),
         {:ok, invite} <- Communities.update_invite(auth, invite, changes) do
      render(conn, :update, invite: invite)
    end
  end

  operation :accept,
    summary: "Join a community through an invite",
    security: [%{"bearer" => []}],
    parameters: [code: @code],
    responses: [
      created: {Schema.Membership, description: "Joined"},
      bad_request: %Reference{"$ref": "#/components/responses/bad_request"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"code" => ~V[required|string|min:1|max:64]}

  def accept(%Conn{assigns: %{auth: %{}}} = conn, %{"code" => code}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, membership} <- Communities.accept_invite(auth, code),
         {:ok, membership} <- IAM.get_membership(auth, membership.community_id) do
      conn |> put_status(:created) |> render(:accept, membership: membership)
    end
  end

  operation :delete,
    summary: "Revoke an invite link",
    security: [%{"bearer" => []}],
    parameters: [code: @code],
    responses: [
      ok: {Schema.Invite, description: "Revoked"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"code" => ~V[required|string|min:1|max:64]}

  def delete(%Conn{assigns: %{auth: %{}}} = conn, %{"code" => code}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, invite} <- Communities.get_invite(code),
         {:ok, invite} <- Communities.revoke_invite(auth, invite) do
      render(conn, :delete, invite: invite)
    end
  end

  operation :email_create,
    summary: "Email invites",
    description: "Each address gets a single use code with the role given for it",
    security: [%{"bearer" => []}],
    parameters: [community_id: @community_id],
    request_body: Schema.EmailInvitesBody,
    responses: [
      created: {%{type: :array, items: Schema.InviteEmail}, description: "Sent"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{
    "community_id" => ~V[required|uuid],
    "note" => ~V[string|max:280],
    "emails" => ~V[required|list|max:50],
    "emails.*.email" => ~V[required|string|min:3|max:254],
    "emails.*.role_key" => ~V[required|string|min:1|max:40]
  }

  def email_create(%Conn{assigns: %{auth: %{}}} = conn, params) do
    %Conn{assigns: %{auth: auth}} = conn
    %{"community_id" => community_id, "emails" => emails} = params

    entries = Enum.map(emails, &%{email: &1["email"], role_key: &1["role_key"]})

    note =
      case String.trim(params["note"] || "") do
        "" -> nil
        text -> text
      end

    with {:ok, community} <- Communities.get_community(id: community_id, archived_at: nil),
         {:ok, sent} <- Communities.email_invites(auth, community, entries, note) do
      conn |> put_status(:created) |> render(:email_create, sent: sent)
    end
  end

  operation :email_delete,
    summary: "Revoke an emailed invite",
    description: "Only that person's code stops working",
    security: [%{"bearer" => []}],
    parameters: [id: [in: :path, schema: %{type: :string, format: :uuid}]],
    responses: [
      ok: {Schema.InviteEmail, description: "Revoked"},
      forbidden: %Reference{"$ref": "#/components/responses/forbidden"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def email_delete(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, invite_email} <- Communities.get_invite_email(id),
         {:ok, invite_email} <- Communities.revoke_email_invite(auth, invite_email) do
      render(conn, :email_delete, invite_email: invite_email)
    end
  end

  operation :mine,
    summary: "List the invites waiting for me",
    description: "Emailed invites not yet used or turned down",
    security: [%{"bearer" => []}],
    responses: [
      ok: {%{type: :array, items: Schema.MyInvite}, description: "OK"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"}
    ]

  def mine(%Conn{assigns: %{auth: %{}}} = conn, _params) do
    %Conn{assigns: %{auth: auth}} = conn
    invites = Communities.list_my_invites(auth)

    inviters =
      invites
      |> Enum.map(& &1.invite.created_by_id)
      |> Accounts.list_users()
      |> Avatars.put_urls()
      |> Map.new(&{&1.id, &1})

    render(conn, :mine, invites: invites, inviters: inviters)
  end

  operation :email_decline,
    summary: "Turn down an emailed invite",
    description: "Its code stops working",
    security: [%{"bearer" => []}],
    parameters: [id: [in: :path, schema: %{type: :string, format: :uuid}]],
    responses: [
      no_content: %Reference{"$ref": "#/components/responses/no_content"},
      not_found: %Reference{"$ref": "#/components/responses/not_found"},
      unauthorized: %Reference{"$ref": "#/components/responses/unauthorized"},
      unprocessable_content: %Reference{"$ref": "#/components/responses/unprocessable_content"}
    ]

  @validate %{"id" => ~V[required|uuid]}

  def email_decline(%Conn{assigns: %{auth: %{}}} = conn, %{"id" => id}) do
    %Conn{assigns: %{auth: auth}} = conn

    with {:ok, invite_email} <- Communities.get_invite_email(id),
         {:ok, _invite_email} <- Communities.decline_email_invite(auth, invite_email) do
      send_resp(conn, :no_content, "")
    end
  end
end
