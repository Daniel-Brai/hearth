defmodule HearthWeb.ChannelCase do
  use ExUnit.CaseTemplate

  import Phoenix.ChannelTest

  @endpoint HearthWeb.Endpoint

  using do
    quote do
      import Phoenix.ChannelTest
      import HearthWeb.ChannelCase

      @endpoint HearthWeb.Endpoint
    end
  end

  setup tags do
    Hearth.DataCase.setup_sandbox(tags)
    :ok
  end

  def push_times(socket, event, payload, count) do
    for _n <- 1..count, do: push(socket, event, payload)

    :ok
  end

  # Pushes run in tasks that would outlive the test's database
  def stop_online_counts do
    :ok = ExUnit.Callbacks.stop_supervised!(HearthWeb.OnlineCounts)

    HearthWeb.OnlineCounts.Tasks
    |> Task.Supervisor.children()
    |> Enum.each(fn pid ->
      ref = Process.monitor(pid)

      receive do
        {:DOWN, ^ref, :process, ^pid, _reason} -> :ok
      end
    end)
  end

  def connected_socket(user) do
    {:ok, token, _claims} = HearthWeb.Guardian.encode_and_sign(user, %{}, token_type: "access")
    {:ok, socket} = connect(HearthWeb.UserSocket, %{}, connect_info: %{auth_token: token})

    socket
  end
end
