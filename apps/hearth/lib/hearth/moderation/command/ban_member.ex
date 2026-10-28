defmodule Hearth.Moderation.Command.BanMember do
  alias Hearth.Accounts.User
  alias Hearth.Communities
  alias Hearth.Communities.Ban
  alias Hearth.Communities.Community
  alias Hearth.Moderation.Action
  alias Hearth.Repo

  @spec execute(User.t(), Community.t(), User.t(), map()) ::
          {:ok, Ban.t()} | {:error, :forbidden | Ecto.Changeset.t()}
  def execute(%User{} = moderator, %Community{} = community, %User{} = target, %{} = params) do
    Repo.transact(fn ->
      with {:ok, ban} <- Communities.ban(moderator, community, target, params),
           {:ok, _action} <- log(moderator, ban, :banned, ban.reason) do
        {:ok, ban}
      end
    end)
  end

  @spec lift(User.t(), Ban.t(), nil | String.t()) ::
          {:ok, Ban.t()} | {:error, :forbidden | Ecto.Changeset.t()}
  def lift(%User{} = moderator, %Ban{} = ban, reason) do
    Repo.transact(fn ->
      with {:ok, ban} <- Communities.lift_ban(moderator, ban),
           {:ok, _action} <- log(moderator, ban, :unbanned, reason) do
        {:ok, ban}
      end
    end)
  end

  defp log(moderator, ban, action, reason) do
    expires_at = if ban.expires_at, do: DateTime.to_iso8601(ban.expires_at)

    line = %Action{
      community_id: ban.community_id,
      actor_id: moderator.id,
      target_id: ban.user_id,
      action: action,
      subject_type: :user,
      subject_id: ban.user_id
    }

    Action.insert(line, %{reason: reason, metadata: %{"expires_at" => expires_at}})
  end
end
