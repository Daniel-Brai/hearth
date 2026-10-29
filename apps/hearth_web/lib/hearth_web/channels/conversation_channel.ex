defmodule HearthWeb.ConversationChannel do
  use HearthWeb, :channel

  alias Hearth.Chat
  alias Hearth.Common
  alias HearthWeb.Typing
  alias Phoenix.Socket

  @impl Phoenix.Channel
  def join("conversation:" <> id, _payload, socket) do
    %Socket{assigns: %{auth: auth}} = socket

    with true <- Common.valid_id?(id),
         {:ok, conversation} <- Chat.get_conversation(auth, id) do
      {:ok, assign(socket, :conversation, conversation)}
    else
      _denied -> {:error, %{reason: "unauthorized"}}
    end
  end

  @impl Phoenix.Channel
  def handle_in("typing", %{"typing" => typing}, socket) when is_boolean(typing) do
    :ok = Typing.relay(socket, socket.assigns.conversation, typing)
    {:noreply, socket}
  end

  def handle_in(_event, _payload, socket), do: {:reply, {:error, %{reason: "unknown"}}, socket}
end
