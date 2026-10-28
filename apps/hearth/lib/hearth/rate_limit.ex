defmodule Hearth.RateLimit do
  use Boundary, deps: [Hearth.Repo], exports: []

  use Hammer, backend: Hearth.RateLimit.Postgres
end
