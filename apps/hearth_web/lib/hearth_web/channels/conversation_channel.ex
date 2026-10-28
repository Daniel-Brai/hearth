defmodule HearthWeb.ConversationChannel do
  use HearthWeb, :channel

  alias Hearth.Chat
  alias Hearth.Common
  alias Phoenix.Socket

  @impl Phoenix.Channel
  def join("conversation:" <> id, _payload, socket) do
    %Socket{assigns: %{auth: auth}} = socket

    with true <- Common.valid_id?(id),
         {:ok, _conversation} <- Chat.get_conversation(auth, id) do
      {:ok, socket}
    else
      _denied -> {:error, %{reason: "unauthorized"}}
    end
  end
end
