defmodule HearthWeb.InviteJSON do
  alias HearthWeb.CommunityJSON
  alias HearthWeb.UserJSON

  @fields ~w[
    id
    code
    role_key
    max_uses
    uses_count
    expires_at
    revoked_at
    created_by_id
    inserted_at
  ]a

  def index(%{links: links, emails: emails}) do
    %{links: Enum.map(links, &serialize/1), emails: Enum.map(emails, &email/1)}
  end

  def create(%{invite: invite}), do: serialize(invite)
  def update(%{invite: invite}), do: serialize(invite)
  def delete(%{invite: invite}), do: serialize(invite)

  def show(%{invite: invite, usable: usable, inviter: inviter} = assigns) do
    community =
      Map.take(assigns.community, ~w[id slug name tagline hue logo_id logo_url member_count]a)

    %{
      code: invite.code,
      usable: usable,
      role_key: invite.role_key,
      role_name: assigns.role_name,
      inviter: UserJSON.summary(inviter),
      community: community
    }
  end

  def accept(%{membership: membership}), do: CommunityJSON.join(%{membership: membership})

  def mine(%{invites: invites, inviters: inviters}) do
    Enum.map(invites, fn %{invite: invite} = invite_email ->
      %{
        id: invite_email.id,
        code: invite.code,
        role_key: invite.role_key,
        inviter: UserJSON.summary(inviters[invite.created_by_id]),
        community: Map.take(invite.community, ~w[id slug name tagline hue logo_id]a),
        expires_at: invite.expires_at,
        inserted_at: invite_email.inserted_at
      }
    end)
  end

  def email_create(%{sent: sent}), do: Enum.map(sent, &email/1)
  def email_delete(%{invite_email: invite_email}), do: email(invite_email)

  @spec serialize(map()) :: map()
  def serialize(invite), do: Map.take(invite, @fields)

  defp email(invite_email) do
    invite_email
    |> Map.take(~w[id email status inserted_at]a)
    |> Map.put(:role_key, invite_email.invite.role_key)
  end
end
