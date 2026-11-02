defmodule Hearth.Repo.Migration do
  # A migration that waits for a lock gives up after a few seconds instead of
  # blocking every query on the table behind it
  # Ecto skips this when a migration sets @disable_ddl_transaction

  defmacro __using__(opts) do
    lock_timeout = Keyword.get(opts, :lock_timeout, up: "5s", down: "10s")

    quote do
      use Ecto.Migration

      if unquote(lock_timeout) do
        def after_begin do
          execute(
            "SET LOCAL lock_timeout TO '#{Keyword.fetch!(unquote(lock_timeout), :up)}'",
            "SET LOCAL lock_timeout TO '#{Keyword.fetch!(unquote(lock_timeout), :down)}'"
          )
        end
      end
    end
  end
end
