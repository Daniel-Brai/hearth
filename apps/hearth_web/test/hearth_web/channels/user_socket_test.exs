defmodule HearthWeb.UserSocketTest do
  use HearthWeb.ChannelCase, async: true

  alias Hearth.TestUtils
  alias HearthWeb.UserSocket

  describe "connect/3" do
    test "fails without a token" do
      assert :error = connect(UserSocket, %{}, connect_info: %{})
    end

    test "fails for a token that isn't valid" do
      assert :error = connect(UserSocket, %{}, connect_info: %{auth_token: "nope"})
    end

    test "connects with an access token" do
      user = TestUtils.register_random_user!()
      socket = connected_socket(user)

      assert socket.assigns.auth.id == user.id
      assert UserSocket.id(socket) == "user_socket:#{user.id}"
    end
  end
end
