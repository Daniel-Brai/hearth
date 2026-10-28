defmodule Hearth do
  default = [
    AI,
    Accounts,
    Auth,
    Chat,
    Common,
    Communities,
    Events,
    Forum,
    IAM,
    Instance,
    Media,
    Moderation,
    Notifications,
    RateLimit,
    Roles,
    Storage,
    Transcripts,
    Voice
  ]

  exports =
    case Mix.env() do
      :test -> [DataCase, TestUtils | default]
      _env -> default
    end

  use Boundary, exports: exports
end
