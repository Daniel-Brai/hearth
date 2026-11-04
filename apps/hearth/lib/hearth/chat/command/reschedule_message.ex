defmodule Hearth.Chat.Command.RescheduleMessage do
  alias Ecto.Changeset
  alias Hearth.Chat.ScheduledMessage
  alias Hearth.Chat.Worker.SendScheduled
  alias Hearth.Repo

  # The job for the old time finds the time changed and does nothing
  @spec execute(ScheduledMessage.t(), DateTime.t()) ::
          {:ok, ScheduledMessage.t()} | {:error, Changeset.t()}
  def execute(%ScheduledMessage{} = scheduled, %DateTime{} = send_at) do
    Repo.transact(fn ->
      with {:ok, scheduled} <-
             scheduled |> ScheduledMessage.reschedule_changeset(send_at) |> Repo.update(),
           {:ok, _job} <- SendScheduled.enqueue(scheduled) do
        {:ok, scheduled}
      end
    end)
  end
end
