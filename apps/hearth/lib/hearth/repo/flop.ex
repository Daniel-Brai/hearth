defmodule Hearth.Repo.Flop do
  use Flop,
    repo: Hearth.Repo,
    max_limit: 100,
    default_pagination_type: :first,
    pagination_types: [:first, :last]
end
