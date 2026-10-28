import Config

# Screening holds what looks unsafe for a person to decide
# local runs open models on ai nodes and hosted sends text and images to OpenRouter and off screens nothing
config :hearth, Hearth.ScreeningPolicy,
  screener: {:system, :atom, "MODERATION_SCREENER", :local},
  # images screens every image on the instance, whatever each community picked
  image_floor: {:system, :atom, "IMAGE_SCREENING_FLOOR", :off}

config :hearth, Hearth.Moderation.Screener,
  threshold: {:system, :float, "MODERATION_THRESHOLD", 0.5},
  # The longest text sent to a model, in characters
  max_text: 4_000

config :hearth, Hearth.Moderation.Screener.Local,
  text_model: {:system, "MODERATION_TEXT_MODEL", "Qwen/Qwen3Guard-Gen-0.6B"},
  image_model: {:system, "MODERATION_IMAGE_MODEL", "Falconsai/nsfw_image_detection"},
  # Calls that arrive within this many milliseconds run together
  batch_size: 4,
  batch_timeout: 50

config :hearth, Hearth.Moderation.Screener.Hosted,
  base_url: "https://openrouter.ai/api/v1",
  api_key: {:system, "OPENROUTER_API_KEY", nil},
  model: {:system, "MODERATION_HOSTED_MODEL", "google/gemini-2.5-flash"},
  receive_timeout: 30_000

config :nx, default_backend: EXLA.Backend

if config_env() == :test do
  import_config "#{config_env()}.exs"
end
