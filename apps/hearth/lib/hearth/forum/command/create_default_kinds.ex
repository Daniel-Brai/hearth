defmodule Hearth.Forum.Command.CreateDefaultKinds do
  alias Ecto.Changeset
  alias Hearth.Common.T
  alias Hearth.Forum.Kind
  alias Hearth.Forum.KindLibrary
  alias Hearth.Repo

  @spec execute(T.id(), String.t()) :: {:ok, [Kind.t()]} | {:error, Changeset.t()}
  def execute(community_id, template) when is_binary(community_id) do
    result =
      Repo.transact(fn ->
        template
        |> KindLibrary.for_template()
        |> Enum.reduce_while({:ok, []}, &insert(community_id, &1, &2))
      end)

    with {:ok, kinds} <- result, do: {:ok, Enum.reverse(kinds)}
  end

  defp insert(community_id, params, {:ok, kinds}) do
    case Kind.insert(%Kind{community_id: community_id}, params) do
      {:ok, kind} -> {:cont, {:ok, [kind | kinds]}}
      {:error, changeset} -> {:halt, {:error, changeset}}
    end
  end
end
