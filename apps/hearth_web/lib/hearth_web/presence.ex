defmodule HearthWeb.Presence do
  use Phoenix.Presence, otp_app: :hearth_web, pubsub_server: Hearth.PubSub

  @topic "online"

  # Every open app joins its user channel so being in it is being online
  @spec track_user(pid(), Hearth.Common.T.id()) :: {:ok, binary()} | {:error, term()}
  def track_user(pid, user_id), do: track(pid, @topic, user_id, %{})

  @spec online_ids() :: [Hearth.Common.T.id()]
  def online_ids, do: @topic |> list() |> Map.keys()
end
