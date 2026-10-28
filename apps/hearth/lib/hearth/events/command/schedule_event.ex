defmodule Hearth.Events.Command.ScheduleEvent do
  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Common.T
  alias Hearth.Events.Event
  alias Hearth.Events.Interest
  alias Hearth.Events.VoiceStart
  alias Hearth.Events.Worker.Remind
  alias Hearth.Repo

  @spec execute(User.t(), T.id(), map()) :: {:ok, Event.t()} | {:error, Changeset.t()}
  def execute(%User{} = host, community_id, %{} = params) do
    event = %Event{community_id: community_id, host_id: host.id}

    Repo.transact(fn ->
      with {:ok, event} <- Event.insert(event, params) do
        :interested = Interest.toggle(event.id, host.id)
        :ok = Remind.schedule(event)
        :ok = VoiceStart.schedule(event)

        {:ok, event}
      end
    end)
  end
end
