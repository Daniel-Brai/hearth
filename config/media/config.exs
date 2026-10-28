import Config

# Upload limits, in megabytes
config :hearth, Hearth.Media,
  max_image_mb: {:system, :integer, "UPLOAD_MAX_IMAGE_MB", 10},
  max_file_mb: {:system, :integer, "UPLOAD_MAX_FILE_MB", 25},
  max_attachments: {:system, :integer, "UPLOAD_MAX_ATTACHMENTS", 10},
  max_video_mb: {:system, :integer, "UPLOAD_MAX_VIDEO_MB", 100},
  max_video_minutes: {:system, :integer, "UPLOAD_MAX_VIDEO_MINUTES", 20},
  multipart_above_mb: 100,
  # AVIF encodes several times slower than WebP so it is off unless asked for
  avif: {:system, :boolean, "IMAGE_AVIF", false}

if config_env() == :test do
  import_config "#{config_env()}.exs"
end
