defmodule HearthWeb.FloodGuard do
  @moduledoc "Per node and in memory while the limits that matter are shared through Hearth.RateLimit"

  use Hammer, backend: :ets, algorithm: :sliding_window
end
