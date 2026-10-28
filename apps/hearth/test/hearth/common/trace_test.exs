defmodule Hearth.Common.TraceTest do
  use ExUnit.Case, async: false

  alias Hearth.Common

  require Record

  Record.defrecordp(
    :span,
    Record.extract(:span, from_lib: "opentelemetry/include/otel_span.hrl")
  )

  # Spans from other tests may land here too, so each assertion matches its own span name
  setup do
    :otel_simple_processor.set_exporter(:otel_exporter_pid, self())
  end

  describe "span/3" do
    test "mark span failed on raise" do
      assert_raise RuntimeError, fn ->
        Common.span("storage.put", %{}, fn -> raise "disk full" end)
      end

      assert_receive {:span, span(name: "storage.put", status: {:status, :error, "disk full"})}
    end

    test "mark span failed on error" do
      assert {:error, :not_converted} =
               Common.span("ffmpeg", %{}, fn -> {:error, :not_converted} end)

      assert_receive {:span, span(name: "ffmpeg", status: {:status, :error, ":not_converted"})}
    end

    test "span work" do
      assert :ok = Common.span("mail.deliver", %{to: "one"}, fn -> :ok end)

      assert_receive {:span,
                      span(name: "mail.deliver", status: :undefined, attributes: attributes)}

      assert %{to: "one"} = :otel_attributes.map(attributes)
    end
  end
end
