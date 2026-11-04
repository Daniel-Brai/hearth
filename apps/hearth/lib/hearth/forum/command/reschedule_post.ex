defmodule Hearth.Forum.Command.ReschedulePost do
  alias Ecto.Changeset
  alias Hearth.Forum.ScheduledPost
  alias Hearth.Forum.Worker.PublishScheduled
  alias Hearth.Repo

  # The job for the old time finds the time changed and does nothing
  @spec execute(ScheduledPost.t(), DateTime.t()) ::
          {:ok, ScheduledPost.t()} | {:error, Changeset.t()}
  def execute(%ScheduledPost{} = scheduled, %DateTime{} = send_at) do
    Repo.transact(fn ->
      with {:ok, scheduled} <-
             scheduled |> ScheduledPost.reschedule_changeset(send_at) |> Repo.update(),
           {:ok, _job} <- PublishScheduled.enqueue(scheduled) do
        {:ok, scheduled}
      end
    end)
  end
end
