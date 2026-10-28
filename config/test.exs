import Config

config :logger, level: :warning

# Spans export at once, so a test can catch them with :otel_exporter_pid
config :opentelemetry, span_processor: :simple
