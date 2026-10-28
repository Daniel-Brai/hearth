defmodule Hearth.RateLimit.Postgres do
  alias Hearth.RateLimit.Bucket

  defmacro __before_compile__(_env) do
    quote do
      @impl Hammer
      def hit(key, scale, limit, cost \\ 1) do
        Bucket.take(key, scale, limit, cost)
      end
    end
  end
end
