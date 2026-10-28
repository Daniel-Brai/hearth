import Config

# off is the default and local runs Whisper on ai nodes
config :hearth, Hearth.TranscriptionPolicy, mode: {:system, "TRANSCRIPTION", "off"}

config :hearth, Hearth.AI, transcriber: Hearth.AI.Whisper

config :hearth, Hearth.AI.Whisper,
  model: {:system, "TRANSCRIBE_MODEL", "openai/whisper-small"},
  # Calls that arrive within this many milliseconds run together
  batch_size: 4,
  batch_timeout: 100

if config_env() == :test do
  import_config "#{config_env()}.exs"
end
