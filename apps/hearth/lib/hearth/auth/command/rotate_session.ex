defmodule Hearth.Auth.Command.RotateSession do
  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Auth.Token
  alias Hearth.Repo

  # The old token is deleted on use so a stolen copy is refused after the owner refreshes
  @spec execute(String.t(), map()) ::
          {:ok, User.t(), String.t()} | {:error, :invalid | :expired | :not_found}
  def execute(session, %{} = meta) when is_binary(session) do
    result =
      Repo.transact(fn ->
        with {:ok, token} <- Token.take_random(:session, session),
             {:ok, user} <- Accounts.get_user(id: token.user_id),
             params = meta |> Map.take([:user_agent, :ip]) |> Map.put(:user_id, user.id),
             {:ok, new_session} <- Token.create_random(:session, params) do
          {:ok, {user, new_session}}
        end
      end)

    case result do
      {:ok, {user, new_session}} -> {:ok, user, new_session}
      error -> error
    end
  end
end
