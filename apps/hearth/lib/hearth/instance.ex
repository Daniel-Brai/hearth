defmodule Hearth.Instance do
  use Boundary,
    deps: [
      Hearth.Auth,
      Hearth.Communities,
      Hearth.Media,
      Hearth.Moderation,
      Hearth.Notifications,
      Hearth.Repo,
      Hearth.Roles,
      Hearth.RTC,
      Hearth.TranscriptionPolicy,
      Hearth.Voice
    ],
    exports: [Settings]

  alias Hearth.Auth
  alias Hearth.Communities
  alias Hearth.Instance.ReleaseCheck
  alias Hearth.Instance.Releases
  alias Hearth.Instance.Settings
  alias Hearth.Media
  alias Hearth.Moderation
  alias Hearth.Notifications
  alias Hearth.Repo
  alias Hearth.Roles
  alias Hearth.RTC
  alias Hearth.TranscriptionPolicy
  alias Hearth.Voice

  require Logger

  @key {__MODULE__, :settings}

  @spec load() :: Settings.t()
  def load do
    settings = %Settings{
      name: config(:instance_name) || "Hearth",
      logo: config(:instance_logo),
      icon: config(:instance_icon),
      sign_in: [:email | Auth.providers()],
      # Read on each call, as the admin can change it while nodes run
      community_creation: nil,
      push_public_key: Notifications.vapid_public_key(),
      upload_limits: Media.limits(),
      screening: Moderation.screening()
    }

    :persistent_term.put(@key, settings)

    settings
  end

  # Only the database is critical
  @spec readiness() :: {:ok | :error, %{database: :ok | :unavailable}}
  def readiness do
    database =
      case Repo.ping(2_000) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.warning("Not ready, the database didn't answer: #{inspect(reason)}")
          :unavailable
      end

    checks = %{database: database}

    case checks |> Map.values() |> Enum.all?(&(&1 == :ok)) do
      true -> {:ok, checks}
      false -> {:error, checks}
    end
  end

  @spec update_status() :: map()
  def update_status do
    current = :hearth |> Application.spec(:vsn) |> to_string()
    check = ReleaseCheck.get()
    latest = get_in(check.latest_version)

    %{
      enabled: Releases.enabled?(),
      current_version: current,
      latest_version: latest,
      update_available: newer?(latest, current),
      release_name: get_in(check.release_name),
      release_url: get_in(check.release_url),
      notes: get_in(check.notes),
      published_at: get_in(check.published_at),
      checked_at: get_in(check.checked_at)
    }
  end

  @spec check_for_update() :: {:ok, map()} | {:error, :disabled | term()}
  def check_for_update do
    with true <- Releases.enabled?(),
         {:ok, release} <- Releases.latest(),
         {:ok, _check} <- ReleaseCheck.put(release) do
      {:ok, update_status()}
    else
      false -> {:error, :disabled}
      error -> error
    end
  end

  defp newer?(nil, _current), do: false

  defp newer?(latest, current) do
    case {Version.parse(latest), Version.parse(current)} do
      {{:ok, latest}, {:ok, current}} -> Version.compare(latest, current) == :gt
      _unparsed -> false
    end
  end

  @spec indexing?() :: boolean()
  def indexing?, do: config(:instance_indexing) != false

  @spec settings() :: Settings.t()
  def settings do
    settings =
      case :persistent_term.get(@key, nil) do
        nil -> load()
        %Settings{} = settings -> settings
      end

    # Read on each call, as these change while nodes run
    %{
      settings
      | community_creation: Communities.creation_mode(),
        roles: Roles.in_cluster(),
        transcription: %{enabled: TranscriptionPolicy.on?()},
        voice: %{enabled: RTC.available?()},
        recording: %{enabled: Voice.recording_available?()}
    }
  end

  defp config(key), do: Application.get_env(:hearth, key)
end
