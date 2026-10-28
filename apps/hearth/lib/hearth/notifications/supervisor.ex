defmodule Hearth.Notifications.Supervisor do
  use Supervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts)
  end

  @impl Supervisor
  if Mix.env() == :test do
    def init(_opts), do: :ignore
  else
    def init(_opts) do
      alias Hearth.Notifications.Listener

      Supervisor.init(
        [
          Listener.Auth,
          Listener.Communities,
          Listener.Forum,
          Listener.Chat,
          Listener.Events,
          Listener.Moderation,
          Listener.Voice,
          Listener.Transcripts
        ],
        strategy: :one_for_one
      )
    end
  end
end
