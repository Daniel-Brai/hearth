defmodule Hearth.Communities.Command.RevokeEmailInvite do
  alias Ecto.Changeset
  alias Hearth.Communities.Invite
  alias Hearth.Communities.InviteEmail
  alias Hearth.Repo

  @spec execute(InviteEmail.t(), :revoked | :declined) ::
          {:ok, InviteEmail.t()} | {:error, Changeset.t()}
  def execute(%InviteEmail{invite: %Invite{} = invite} = invite_email, status \\ :revoked) do
    Repo.transact(fn ->
      with {:ok, _invite} <- Invite.revoke(invite),
           {:ok, invite_email} <- InviteEmail.update(invite_email, %{status: status}) do
        {:ok, %{invite_email | invite: invite}}
      end
    end)
  end
end
