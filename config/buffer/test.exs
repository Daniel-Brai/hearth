import Config

# Tests see buffered writes straight away instead of after a flush
config :hearth, Hearth.Buffer, write_through: true
