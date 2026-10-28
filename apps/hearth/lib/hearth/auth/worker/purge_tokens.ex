defmodule Hearth.Auth.Worker.PurgeTokens do
  use Oban.Worker,
    queue: :default,
    max_attempts: 3,
    unique: [period: :infinity, states: :incomplete]

  alias Hearth.Auth.Token

  @impl Oban.Worker
  def perform(%Oban.Job{}), do: Token.delete_expired_tokens()
end
