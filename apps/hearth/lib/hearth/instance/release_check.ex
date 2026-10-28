defmodule Hearth.Instance.ReleaseCheck do
  use Hearth.Repo.Schema, prefix: "instance", primary_key: {:id, :id, autogenerate: false}

  alias Ecto.Changeset
  alias Hearth.Instance.Release

  @notes_length 2_000
  @fields ~w[latest_version release_name release_url notes published_at checked_at]a

  schema "release_checks" do
    field :latest_version, :string
    field :release_name, :string
    field :release_url, :string
    field :notes, :string
    field :published_at, :utc_datetime_usec
    field :checked_at, :utc_datetime_usec
  end

  @type t :: %__MODULE__{
          id: integer(),
          latest_version: nil | String.t(),
          release_name: nil | String.t(),
          release_url: nil | String.t(),
          notes: nil | String.t(),
          published_at: nil | DateTime.t(),
          checked_at: DateTime.t()
        }

  @spec get() :: nil | t()
  def get, do: get(id: 1)

  @spec put(nil | Release.t()) :: {:ok, t()} | {:error, Changeset.t()}
  def put(release) do
    %__MODULE__{id: 1}
    |> Changeset.change(release |> values() |> Map.put(:checked_at, DateTime.utc_now()))
    |> Repo.insert(on_conflict: {:replace, @fields}, conflict_target: :id)
  end

  defp values(nil),
    do: %{latest_version: nil, release_name: nil, release_url: nil, notes: nil, published_at: nil}

  defp values(%Release{} = release) do
    %{
      latest_version: release.version,
      release_name: release.name,
      release_url: release.url,
      notes: if(release.notes, do: String.slice(release.notes, 0, @notes_length)),
      published_at: release.published_at
    }
  end
end
