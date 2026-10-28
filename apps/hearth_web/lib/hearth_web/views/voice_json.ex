defmodule HearthWeb.VoiceJSON do
  @session ~w[id room_id community_id host_id event_id post_id mode topic started_at ended_at]a
  @participant ~w[user_id role hand_raised_at self_muted server_muted]a

  def live_index(%{sessions: sessions, recording: recording, people: people}) do
    Enum.map(sessions, fn session ->
      %{session: session, recording: recording[session.id]}
      |> session()
      |> Map.put(:people, people[session.id])
    end)
  end

  def session(%{session: session} = assigns) do
    session
    |> Map.take(@session)
    |> Map.put(:recording, Map.get(assigns, :recording, false))
  end

  def state(%{session: session, snapshot: snapshot} = assigns) do
    %{
      session:
        session(%{
          session: %{session | mode: snapshot.mode},
          recording: snapshot.recording != nil
        }),
      host_tools: assigns.host_tools,
      may_record: assigns.may_record,
      recording: snapshot.recording,
      share: snapshot.share,
      hands: snapshot.hands,
      speaking: snapshot.speaking,
      participants: Enum.map(snapshot.participants, &Map.take(&1, @participant))
    }
  end
end
