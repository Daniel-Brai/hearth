defmodule Hearth.Moderation.Command.FileReport do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Moderation.Item
  alias Hearth.Moderation.Report
  alias Hearth.Moderation.Subject
  alias Hearth.Repo

  # The third element says whether the item is new so moderators are told once
  @spec execute(User.t(), Subject.t(), map()) ::
          {:ok, Item.t(), boolean()} | {:error, :already_reported | Changeset.t()}
  def execute(%User{} = reporter, %Subject{} = subject, %{} = params) do
    result =
      Repo.transact(fn ->
        with {:ok, item, new?} <- open_item(subject),
             :ok <- first_report(item, reporter),
             {:ok, _report} <- insert_report(item, reporter, params) do
          :ok = Item.count_report(item)
          {:ok, {%{item | report_count: item.report_count + 1}, new?}}
        end
      end)

    case result do
      {:ok, {item, new?}} -> {:ok, item, new?}
      {:error, _reason} = error -> error
    end
  end

  defp open_item(%Subject{} = subject) do
    case Item.pending(subject.type, subject.content.id) do
      %Item{} = item -> {:ok, item, false}
      nil -> insert_item(subject)
    end
  end

  defp insert_item(subject) do
    item = %Item{
      community_id: subject.community_id,
      room_id: subject.room_id,
      source: if(Subject.direct?(subject), do: :instance, else: :report),
      subject_type: subject.type,
      subject_id: subject.content.id,
      author_id: subject.author_id
    }

    with {:ok, item} <- Item.insert(item, %{}), do: {:ok, item, true}
  end

  defp first_report(item, reporter) do
    case Report.exists_for?(item, reporter.id) do
      true -> {:error, :already_reported}
      false -> :ok
    end
  end

  defp insert_report(item, reporter, params) do
    Report.insert(%Report{item_id: item.id, reporter_id: reporter.id}, params)
  end
end
