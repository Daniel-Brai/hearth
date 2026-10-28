defmodule Hearth.Communities.Command.BanMember do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Communities.Ban
  alias Hearth.Communities.Community
  alias Hearth.IAM
  alias Hearth.Repo

  @spec execute(User.t(), Community.t(), User.t(), map()) ::
          {:ok, Ban.t()} | {:error, Changeset.t()}
  def execute(%User{} = moderator, %Community{} = community, %User{} = target, %{} = params) do
    ban = %Ban{community_id: community.id, user_id: target.id, banned_by_id: moderator.id}

    Repo.transact(fn ->
      :ok = Ban.close_expired(community.id, target.id)

      with {:ok, ban} <- Ban.insert(ban, params) do
        :ok = IAM.leave(target, community.id)
        {:ok, ban}
      end
    end)
  end
end
