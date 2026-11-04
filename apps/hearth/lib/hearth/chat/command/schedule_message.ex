defmodule Hearth.Chat.Command.ScheduleMessage do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Chat.ScheduledMessage
  alias Hearth.Chat.Worker.SendScheduled
  alias Hearth.Repo

  @most 50

  @spec execute(User.t(), keyword(), map()) ::
          {:ok, ScheduledMessage.t()} | {:error, :too_many | Changeset.t()}
  def execute(%User{} = author, place, %{} = params) when is_list(place) do
    scheduled = struct!(%ScheduledMessage{author_id: author.id}, place)

    Repo.transact(fn ->
      with :ok <- room_for(author),
           {:ok, scheduled} <- ScheduledMessage.insert(scheduled, params),
           {:ok, _job} <- SendScheduled.enqueue(scheduled) do
        {:ok, scheduled}
      end
    end)
  end

  defp room_for(author) do
    case ScheduledMessage.count_for(author.id) < @most do
      true -> :ok
      false -> {:error, :too_many}
    end
  end
end
