defmodule HearthWeb.Schema.Instance do
  use JSV.Schema

  alias HearthWeb.Schema.Recording
  alias HearthWeb.Schema.Screening
  alias HearthWeb.Schema.Transcription
  alias HearthWeb.Schema.UploadLimits
  alias HearthWeb.Schema.Voice

  defschema %{
    title: "Instance",
    type: :object,
    required: ~w[
      name
      logo
      icon
      sign_in
      community_creation
      push_public_key
      upload_limits
      screening
      roles
      transcription
      voice
      recording
    ]a,
    properties: %{
      name: string(),
      logo: nullable(string(description: "Null uses Hearth's")),
      icon: nullable(string(description: "Null uses Hearth's")),
      sign_in: array_of(enum(~w[email github google])),
      community_creation: enum(~w[admins request anyone]),
      push_public_key: nullable(string(description: "Null when push is off")),
      upload_limits: UploadLimits,
      screening: Screening,
      transcription: Transcription,
      voice: Voice,
      recording: Recording,
      roles:
        array_of(enum(~w[web rtc media ai]),
          description: "A feature whose role is missing is off"
        )
    }
  }
end
