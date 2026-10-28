defmodule Hearth.Voice.Command.ChangeParticipant do
  alias Hearth.Common.T
  alias Hearth.Moderation.Action
  alias Hearth.Repo
  alias Hearth.Voice.Participant
  alias Hearth.Voice.Session

  @type log :: %{actor_id: T.id(), action: Action.action(), session: Session.t()}

  @spec execute(Participant.t(), map(), nil | log()) ::
          {:ok, Participant.t()} | {:error, Ecto.Changeset.t()}
  def execute(%Participant{} = participant, %{} = changes, nil),
    do: Participant.put(participant, changes)

  def execute(%Participant{} = participant, %{} = changes, %{} = log) do
    Repo.transact(fn ->
      with {:ok, participant} <- Participant.put(participant, changes),
           {:ok, _action} <- log_action(participant, log) do
        {:ok, participant}
      end
    end)
  end

  defp log_action(participant, %{session: session} = log) do
    action = %Action{
      community_id: session.community_id,
      actor_id: log.actor_id,
      target_id: participant.user_id,
      action: log.action,
      subject_type: :room,
      subject_id: session.room_id
    }

    Action.insert(action, %{metadata: %{session_id: session.id}})
  end
end
