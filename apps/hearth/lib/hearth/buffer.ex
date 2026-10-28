defmodule Hearth.Buffer do
  use Boundary, deps: [], exports: []

  @callback flush(entries :: [{term(), term(), integer(), pos_integer()}]) :: :ok

  defmacro __using__(opts) do
    every = Keyword.fetch!(opts, :every)

    quote do
      @behaviour Hearth.Buffer

      @doc false
      def child_spec(_opts) do
        %{id: __MODULE__, start: {Hearth.Buffer, :start_link, [__MODULE__, unquote(every)]}}
      end
    end
  end

  @doc false
  @spec start_link(module(), pos_integer()) :: GenServer.on_start() | :ignore
  def start_link(buffer, every) do
    case write_through?() do
      true ->
        :ignore

      false ->
        PartitionedBuffer.Map.start_link(
          name: buffer,
          processor: &buffer.flush/1,
          processing_interval_ms: every,
          processing_batch_size: 500
        )
    end
  end

  @spec put_newer(module(), term(), term(), integer()) :: :ok
  def put_newer(buffer, key, value, version) do
    case write_through?() do
      true -> buffer.flush([{key, value, version, 1}])
      false -> PartitionedBuffer.Map.put_newer(buffer, key, value, version)
    end
  end

  defp write_through? do
    :hearth
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(:write_through, false)
  end
end
