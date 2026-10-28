import Config

# Tests run as an instance that transcribes unless they say otherwise
config :hearth, Hearth.TranscriptionPolicy, mode: "local"

config :hearth, Hearth.AI, transcriber: Hearth.AI.TranscriberStub
