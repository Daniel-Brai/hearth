defmodule Hearth.Voice.Supervisor do
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  # The drain starts last so it stops first while the sessions are up
  # Uploads stop last after the sessions that start them
  @impl Supervisor
  def init(_opts) do
    children = [
      {Task.Supervisor, name: Hearth.Voice.TaskSupervisor},
      {Task.Supervisor, name: Hearth.Voice.CaptionTasks},
      {DynamicSupervisor, name: Hearth.Voice.LiveSupervisor, strategy: :one_for_one},
      Hearth.Voice.Drain
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
