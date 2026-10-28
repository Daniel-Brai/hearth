defmodule Hearth.Accounts.Settings do
  use Ecto.Schema

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.TranscriptionPolicy

  @fields ~w[
    theme
    ui_sounds
    play_sounds
    haptics
    captions_on
    compact_feeds
    sidebar_collapsed
    tour_done
    key_bindings
    notification_prefs
    digest
  ]a

  @primary_key false

  embedded_schema do
    field :theme, Ecto.Enum, values: ~w[system light dark]a, default: :system
    field :ui_sounds, :boolean, default: true
    field :play_sounds, :boolean, default: true
    field :haptics, :boolean, default: true
    field :captions_on, :boolean, default: false
    field :compact_feeds, :boolean, default: false
    field :sidebar_collapsed, :boolean, default: false
    field :tour_done, :boolean, default: false
    field :key_bindings, :map, default: %{}
    field :notification_prefs, :map, default: %{}
    field :digest, Ecto.Enum, values: ~w[daily weekly off]a, default: :weekly
  end

  @type t :: %__MODULE__{
          theme: :system | :light | :dark,
          ui_sounds: boolean(),
          play_sounds: boolean(),
          haptics: boolean(),
          captions_on: boolean(),
          compact_feeds: boolean(),
          sidebar_collapsed: boolean(),
          tour_done: boolean(),
          key_bindings: map(),
          notification_prefs: map(),
          digest: :daily | :weekly | :off
        }

  @spec changeset(t(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = settings, %{} = params) do
    settings
    |> cast(params, @fields)
    |> validate_required(@fields)
    |> validate_change(:captions_on, &captions_allowed/2)
  end

  # Captions are speech turned into text so the instance has to allow it
  defp captions_allowed(:captions_on, true) do
    case TranscriptionPolicy.check() do
      :ok -> []
      {:error, :transcription_off} -> [captions_on: "are off on this instance"]
    end
  end

  defp captions_allowed(:captions_on, false), do: []
end
