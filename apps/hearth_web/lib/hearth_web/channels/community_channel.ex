defmodule HearthWeb.CommunityChannel do
  use HearthWeb, :channel

  alias Hearth.Common
  alias Hearth.Communities
  alias Phoenix.Socket

  @impl Phoenix.Channel
  def join("community:" <> id, _payload, socket) do
    %Socket{assigns: %{auth: auth}} = socket

    with true <- Common.valid_id?(id),
         {:ok, community} <- Communities.get_community(id: id),
         true <- Communities.readable?(community, auth) do
      {:ok, socket}
    else
      _denied -> {:error, %{reason: "unauthorized"}}
    end
  end
end
