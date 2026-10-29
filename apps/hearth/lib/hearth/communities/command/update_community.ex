defmodule Hearth.Communities.Command.UpdateCommunity do
  alias Ecto.Changeset
  alias Hearth.Communities.Community
  alias Hearth.Communities.CommunityCategory
  alias Hearth.Repo

  @spec execute(Community.t(), map()) ::
          {:ok, Community.t()}
          | {:error, :too_many_categories | :unknown_category | Changeset.t()}
  def execute(%Community{} = community, %{} = params) do
    Repo.transact(fn ->
      with {:ok, updated} <- Community.update(community, params),
           :ok <- CommunityCategory.put(updated, params[:categories]) do
        {:ok, updated}
      end
    end)
  end
end
