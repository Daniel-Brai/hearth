defmodule HearthWeb.PostChannel do
  use HearthWeb, :channel

  alias Hearth.Common
  alias Hearth.Communities
  alias Hearth.Forum
  alias Phoenix.Socket

  @impl Phoenix.Channel
  def join("post:" <> id, _payload, socket) do
    %Socket{assigns: %{auth: auth}} = socket

    with true <- Common.valid_id?(id),
         {:ok, post} <- Forum.get_post(id: id),
         {:ok, community} <- Communities.get_community(id: post.community_id),
         true <- Communities.readable?(community, auth) do
      {:ok, socket}
    else
      _denied -> {:error, %{reason: "unauthorized"}}
    end
  end
end
