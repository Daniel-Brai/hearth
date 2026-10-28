defmodule Hearth.Common.T do
  @type id :: Ecto.UUID.t()

  @type username :: String.t()

  @type email :: String.t()

  @type slug :: String.t()

  # Stored raw, only browsers render it
  @type markdown :: String.t()
end
