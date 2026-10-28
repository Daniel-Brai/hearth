defmodule Hearth.Media.Listener.Accounts do
  use GenServer

  alias Hearth.Accounts
  alias Hearth.Accounts.AvatarChanged
  alias Hearth.Media.Worker.DeleteMedia

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Accounts.subscribe_to_pubsub()

    {:ok, nil}
  end

  # Every node hears the event, and the job's uniqueness keeps it to one delete
  @impl GenServer
  def handle_info(%AvatarChanged{previous_avatar_id: media_id}, state) when is_binary(media_id) do
    {:ok, _job} = %{media_id: media_id} |> DeleteMedia.new() |> Oban.insert()

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}
end
