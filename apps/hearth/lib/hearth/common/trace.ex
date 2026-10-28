defmodule Hearth.Common.Trace do
  require OpenTelemetry.Tracer, as: Tracer

  # A span that ends failed when the work returns an error or raises, so slow and broken calls stand out
  @spec span(String.t(), map(), (-> result)) :: result when result: term()
  def span(name, attributes, fun) when is_binary(name) and is_function(fun, 0) do
    Tracer.with_span name, %{attributes: attributes} do
      try do
        tap(fun.(), &mark/1)
      rescue
        exception ->
          Tracer.record_exception(exception, __STACKTRACE__)
          Tracer.set_status(OpenTelemetry.status(:error, Exception.message(exception)))
          reraise exception, __STACKTRACE__
      end
    end
  end

  defp mark({:error, reason}),
    do: :error |> OpenTelemetry.status(inspect(reason)) |> Tracer.set_status()

  defp mark(_result), do: :ok
end
