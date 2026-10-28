defmodule Hearth.Communities.Command.EmailInvite do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Common
  alias Hearth.Communities.Community
  alias Hearth.Communities.Invite
  alias Hearth.Communities.InviteEmail
  alias Hearth.Repo

  @valid_days 14

  @spec execute(User.t(), Community.t(), [%{email: String.t(), role_key: String.t()}]) ::
          {:ok, [InviteEmail.t()]} | {:error, Changeset.t()}
  def execute(%User{} = user, %Community{} = community, entries) when is_list(entries) do
    expires_at = DateTime.add(DateTime.utc_now(), @valid_days, :day)

    Repo.transact(fn ->
      entries
      |> Enum.uniq_by(&Common.normalize(&1.email))
      |> Enum.reduce_while({:ok, []}, &insert(user, community, expires_at, &1, &2))
    end)
  end

  defp insert(user, community, expires_at, entry, {:ok, sent}) do
    invite = %Invite{community_id: community.id, created_by_id: user.id}
    invite_params = %{"role_key" => entry.role_key, "max_uses" => 1, "expires_at" => expires_at}

    with {:ok, invite} <- Invite.insert(invite, invite_params),
         {:ok, row} <- InviteEmail.insert(%InviteEmail{invite_id: invite.id}, email_params(entry)) do
      {:cont, {:ok, [%{row | invite: invite} | sent]}}
    else
      {:error, changeset} -> {:halt, {:error, changeset}}
    end
  end

  defp email_params(entry), do: %{email: entry.email, sent_at: DateTime.utc_now()}
end
