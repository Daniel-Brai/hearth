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

  def connected_socket(user) do
    {:ok, token, _claims} = HearthWeb.Guardian.encode_and_sign(user, %{}, token_type: "access")
    {:ok, socket} = connect(HearthWeb.UserSocket, %{}, connect_info: %{auth_token: token})

    socket
  end
end
