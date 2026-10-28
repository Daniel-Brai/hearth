defmodule Hearth.Communities.Command.ApproveRequest do
  alias Ecto.Changeset
  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Communities.Command.CreateCommunity
  alias Hearth.Communities.Request
  alias Hearth.Repo

  @spec execute(User.t(), Request.t()) ::
          {:ok, Request.t()} | {:error, :not_found | Changeset.t()}
  def execute(%User{} = admin, %Request{} = request) do
    params = Map.take(request, ~w[name tagline description hue visibility template]a)

    Repo.transact(fn ->
      with {:ok, requester} <- Accounts.get_user(id: request.requester_id),
           {:ok, community} <- CreateCommunity.execute(requester, params, admin) do
        Request.approve(request, admin.id, community.id)
      end
    end)
  end
end
