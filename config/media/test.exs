import Config

config :hearth, Hearth.Media,
  max_image_mb: 10,
  max_file_mb: 25,
  max_video_mb: 100,
  max_video_minutes: 20,
  multipart_above_mb: 1,
  avif: false
