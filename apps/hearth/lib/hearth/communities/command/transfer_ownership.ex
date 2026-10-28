defmodule Hearth.Communities.Command.TransferOwnership do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Communities.Community
  alias Hearth.IAM
  alias Hearth.Repo

  @spec execute(User.t(), Community.t(), User.t()) ::
          {:ok, Community.t()} | {:error, :not_found | Changeset.t()}
  def execute(%User{} = owner, %Community{} = community, %User{} = to) do
    keys =
      community.id
      |> IAM.list_roles()
      |> Enum.map(& &1.key)

    step_down = if "maintainer" in keys, do: "maintainer", else: "moderator"

    Repo.transact(fn ->
      with {:ok, new} <- IAM.get_membership(to, community.id),
           {:ok, old} <- IAM.get_membership(owner, community.id),
           {:ok, _new} <- IAM.set_roles(new, ["owner"]),
           {:ok, _old} <- IAM.set_roles(old, [step_down]) do
        Community.transfer(community, to.id)
      end
    end)
  end
end
