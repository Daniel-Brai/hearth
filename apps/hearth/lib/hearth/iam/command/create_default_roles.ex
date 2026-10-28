defmodule Hearth.IAM.Command.CreateDefaultRoles do
  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.IAM.Role
  alias Hearth.IAM.Spec
  alias Hearth.Repo

  @defaults [
    %{key: "owner", name: "Owner", position: 0, is_system: true},
    %{key: "moderator", name: "Moderator", position: 1},
    %{key: "member", name: "Member", position: 2, is_default: true}
  ]

  @spec execute(T.id()) :: {:ok, [Role.t()]} | {:error, Changeset.t()}
  def execute(community_id) when is_binary(community_id) do
    result =
      Repo.transact(fn ->
        Enum.reduce_while(@defaults, {:ok, []}, &insert(community_id, &1, &2))
      end)

    with {:ok, roles} <- result, do: {:ok, Enum.reverse(roles)}
  end

  defp insert(community_id, default, {:ok, roles}) do
    params =
      Map.merge(default, %{
        community_id: community_id,
        permissions: Spec.permissions_for("community." <> default.key)
      })

    case Role.insert(%Role{}, params) do
      {:ok, role} -> {:cont, {:ok, [role | roles]}}
      {:error, changeset} -> {:halt, {:error, changeset}}
    end
  end
end
