defmodule Hearth.Instance.Settings do
  @enforce_keys ~w[name sign_in community_creation upload_limits screening]a
  defstruct ~w[
    name
    logo
    icon
    sign_in
    community_creation
    upload_limits
    screening
    push_public_key
    roles
    transcription
    voice
    recording
  ]a

  @type t :: %__MODULE__{
          name: String.t(),
          logo: nil | String.t(),
          icon: nil | String.t(),
          sign_in: [:email | :github | :google],
          community_creation: nil | :admins | :request | :anyone,
          push_public_key: nil | String.t(),
          upload_limits: map(),
          screening: %{enabled: boolean(), image_floor: boolean()},
          roles: nil | [:web | :rtc | :media | :ai],
          transcription: nil | %{enabled: boolean()},
          voice: nil | %{enabled: boolean()},
          recording: nil | %{enabled: boolean()}
        }
end
