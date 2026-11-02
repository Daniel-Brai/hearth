defmodule Hearth.RTC.Route do
  # What a peer has to open and close to match a new route

  alias Hearth.Common.T
  alias Hearth.RTC.Peer

  @type kind :: :audio | :video
  @type source :: {T.id(), kind()}

  @type changes :: %{
          open: [kind()],
          close: [kind()],
          subscribe: [source()],
          unsubscribe: [source()]
        }

  @spec changes(Peer.route(), [kind()], [source()]) :: changes()
  def changes(route, sending, receiving) do
    sends = Enum.filter([:audio, :video], &sends?(route, &1))

    %{
      open: sends -- sending,
      close: sending -- sends,
      subscribe: Enum.uniq(route.receive) -- receiving,
      unsubscribe: receiving -- route.receive
    }
  end

  @spec changed?(changes()) :: boolean()
  def changed?(changes), do: changes |> Map.values() |> Enum.any?(&(&1 != []))

  defp sends?(route, :audio), do: route.send_audio
  defp sends?(route, :video), do: route.send_video
end
