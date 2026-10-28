defmodule Hearth.Voice.Command.EndSession do
  alias Hearth.Repo
  alias Hearth.Voice.Participant
  alias Hearth.Voice.Session

  @spec execute(Session.t()) :: {:ok, Session.t()}
  def execute(%Session{} = session) do
    Repo.transact(fn ->
      {:ok, session} = Session.finish(session)
      :ok = Participant.leave_all(session.id)

      {:ok, session}
    end)
  end
end
