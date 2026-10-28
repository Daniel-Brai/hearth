defmodule Hearth.Moderation.Command.HoldContent do
  alias Hearth.Moderation.Command.SetContentStatus
  alias Hearth.Moderation.Item
  alias Hearth.Moderation.Subject
  alias Hearth.Repo

  @spec execute(Subject.t(), :automatic | :instance, map()) ::
          {:ok, Item.t()} | {:error, Ecto.Changeset.t()}
  def execute(%Subject{} = subject, source, %{} = params)
      when source in [:automatic, :instance] do
    Repo.transact(fn ->
      with {:ok, item} <- queue(subject, source, params),
           :ok <- SetContentStatus.execute(subject, :pending) do
        {:ok, item}
      end
    end)
  end

  defp queue(subject, source, params) do
    case Item.pending(subject.type, subject.content.id) do
      %Item{} = item ->
        Item.hold(item)

      nil ->
        # The instance queue is found by having no community
        community_id = if source == :automatic, do: subject.community_id

        item = %Item{
          community_id: community_id,
          room_id: if(source == :automatic, do: subject.room_id),
          source: source,
          held: true,
          subject_type: subject.type,
          subject_id: subject.content.id,
          author_id: subject.author_id
        }

        Item.insert(item, params)
    end
  end
end
