defmodule Hearth.Forum.Command.SchedulePost do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Communities.Community
  alias Hearth.Forum.ScheduledPost
  alias Hearth.Forum.Worker.PublishScheduled
  alias Hearth.Repo

  @most 50

  @spec execute(User.t(), Community.t(), map()) ::
          {:ok, ScheduledPost.t()} | {:error, :too_many | Changeset.t()}
  def execute(%User{} = author, %Community{} = community, %{} = params) do
    scheduled = %ScheduledPost{author_id: author.id, community_id: community.id}

    Repo.transact(fn ->
      with :ok <- room_for(author),
           {:ok, scheduled} <- ScheduledPost.insert(scheduled, params),
           {:ok, _job} <- PublishScheduled.enqueue(scheduled) do
        {:ok, scheduled}
      end
    end)
  end

  defp room_for(author) do
    case ScheduledPost.count_for(author.id) < @most do
      true -> :ok
      false -> {:error, :too_many}
    end
  end
end
