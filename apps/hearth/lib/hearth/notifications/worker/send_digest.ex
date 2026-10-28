defmodule Hearth.Notifications.Worker.SendDigest do
  use Oban.Worker,
    queue: :digests,
    max_attempts: 3,
    unique: [period: 20 * 3_600, keys: [:user_id]]

  alias Hearth.Accounts
  alias Hearth.Common.T
  alias Hearth.Notifications
  alias Hearth.Notifications.Digest

  @spec job(T.id()) :: Oban.Job.changeset()
  def job(user_id), do: new(%{user_id: user_id})

  @impl Oban.Worker
  def perform(%Oban.Job{args: %{"user_id" => user_id}}) do
    with {:ok, user} <- Accounts.get_user(id: user_id, deleted_at: nil),
         period when period in [:daily, :weekly] <- user.settings.digest,
         %{} = catch_up <- Digest.build(user, period, since(period)) do
      Notifications.send(user, catch_up)
    end

    :ok
  end

  defp since(:daily), do: DateTime.add(DateTime.utc_now(), -1, :day)
  defp since(:weekly), do: DateTime.add(DateTime.utc_now(), -7, :day)
end
