defmodule HearthWeb.UserSocket do
  @moduledoc "The token is sent as the socket's auth token, never in the URL."

  use Phoenix.Socket

  alias HearthWeb.Guardian
  alias Phoenix.Socket

  channel "user:*", HearthWeb.UserChannel
  channel "community:*", HearthWeb.CommunityChannel
  channel "room:*", HearthWeb.RoomChannel
  channel "conversation:*", HearthWeb.ConversationChannel
  channel "post:*", HearthWeb.PostChannel
  channel "voice:*", HearthWeb.VoiceChannel

  @impl Phoenix.Socket
  def connect(_params, socket, %{auth_token: token}) when is_binary(token) do
    case Guardian.resource_from_token(token, %{"typ" => "access"}) do
      {:ok, user, _claims} -> {:ok, assign(socket, :auth, user)}
      {:error, _reason} -> :error
    end
  end

  def connect(_params, _socket, _connect_info), do: :error

  @impl Phoenix.Socket
  def id(%Socket{assigns: %{auth: %{id: id}}}), do: "user_socket:#{id}"
end
