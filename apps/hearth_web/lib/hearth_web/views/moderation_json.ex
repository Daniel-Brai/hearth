defmodule HearthWeb.ModerationJSON do
  alias HearthWeb.PageJSON
  alias HearthWeb.UserJSON

  @item_fields ~w[
    id
    community_id
    room_id
    source
    status
    subject_type
    subject_id
    reason
    note
    score
    report_count
    reviewed_at
    inserted_at
  ]a

  def queue(%{page: page} = assigns) do
    %{data: Enum.map(page.data, &item(&1, assigns)), meta: PageJSON.meta(page.meta)}
  end

  def show(%{item: item} = assigns), do: item(item, assigns)

  def counts(%{counts: counts}), do: %{counts: counts}

  def screening_summary(%{summary: summary}), do: summary

  def level(%{level: level, effective: effective}), do: %{level: level, effective: effective}

  def content(%{subject: subject}) do
    %{subject_type: subject.type, subject_id: subject.content.id, status: subject.content.status}
  end

  def log(%{page: page, people: people}) do
    %{data: Enum.map(page.data, &action(&1, people)), meta: PageJSON.meta(page.meta)}
  end

  @spec item(map(), map()) :: map()
  def item(item, assigns) do
    %{subjects: subjects, reports: reports, people: people, attachments: attachments} = assigns

    item
    |> Map.take(@item_fields)
    |> Map.merge(%{
      reports:
        reports
        |> Map.get(item.id, [])
        |> Enum.map(&Map.take(&1, ~w[reason note inserted_at]a)),
      subject: subject(subjects[item.id], people, attachments),
      author: UserJSON.summary(people[item.author_id]),
      reviewed_by: UserJSON.summary(people[item.reviewed_by_id])
    })
  end

  defp subject(nil, _people, _attachments), do: nil

  defp subject(subject, people, attachments) do
    content = subject.content

    %{
      type: subject.type,
      id: content.id,
      author: UserJSON.summary(people[subject.author_id]),
      title: Map.get(content, :title),
      body: content.body,
      status: content.status,
      post_id: subject.post_id,
      room_id: subject.room_id,
      conversation_id: subject.conversation_id,
      inserted_at: content.inserted_at,
      attachments: Map.get(attachments, content.id, [])
    }
  end

  defp action(action, people) do
    action
    |> Map.take(~w[id action subject_type subject_id reason metadata inserted_at]a)
    |> Map.merge(%{
      actor: UserJSON.summary(people[action.actor_id]),
      target: UserJSON.summary(people[action.target_id])
    })
  end
end
