defmodule HearthWeb.Schema.InviteList do
  use JSV.Schema

  alias HearthWeb.Schema.Invite
  alias HearthWeb.Schema.InviteEmail

  defschema %{
    title: "InviteList",
    type: :object,
    required: [:links, :emails],
    properties: %{
      links: array_of(Invite),
      emails: array_of(InviteEmail)
    }
  }
end
