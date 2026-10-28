defmodule Hearth.Events.Event do
  use Hearth.Repo.Schema, prefix: "events"

  import Ecto.Changeset

  alias Ecto.Changeset
  alias Hearth.Common.T

  @repeats ~w[none daily weekly biweekly monthly]a
  @fields ~w[
    title
    description
    starts_at
    duration_min
    timezone
    repeat
    place
    room_id
    url
    talk_mode
  ]a
  @changeable @fields

  schema "events" do
    field :community_id, Ecto.UUID
    field :host_id, Ecto.UUID
    field :room_id, Ecto.UUID
    field :title, :string
    field :description, :string
    field :starts_at, :utc_datetime_usec
    field :duration_min, :integer
    field :timezone, :string, default: "Etc/UTC"
    field :repeat, Ecto.Enum, values: @repeats, default: :none
    field :place, Ecto.Enum, values: [:room, :link]
    field :url, :string
    field :talk_mode, Ecto.Enum, values: [:stage, :open]
    field :cancelled_at, :utc_datetime_usec
    field :next_starts_at, :utc_datetime_usec, virtual: true

    timestamps()
  end

  @type t :: %__MODULE__{
          id: T.id(),
          community_id: T.id(),
          host_id: nil | T.id(),
          room_id: nil | T.id(),
          title: String.t(),
          description: nil | String.t(),
          starts_at: DateTime.t(),
          duration_min: integer(),
          timezone: String.t(),
          repeat: :none | :daily | :weekly | :biweekly | :monthly,
          place: :room | :link,
          url: nil | String.t(),
          talk_mode: nil | :stage | :open,
          cancelled_at: nil | DateTime.t(),
          next_starts_at: nil | DateTime.t()
        }

  @spec changeset(struct(), map()) :: Changeset.t()
  def changeset(%__MODULE__{} = event, %{} = params) do
    event
    |> cast(params, @fields)
    |> update_change(:title, &String.trim/1)
    |> validate_required(@fields -- ~w[description repeat room_id url talk_mode]a)
    |> validate_length(:title, max: 120)
    |> validate_length(:description, max: 4_000)
    |> validate_number(:duration_min, greater_than_or_equal_to: 5, less_than_or_equal_to: 720)
    |> validate_change(:timezone, &known_zone/2)
    |> validate_place()
    |> validate_future()
    |> check_constraint(:place, name: :place_has_target, message: "needs a room or a link")
  end

  @spec cancel(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def cancel(%__MODULE__{} = event) do
    event
    |> change(cancelled_at: DateTime.utc_now())
    |> Repo.update()
  end

  @spec restore(t()) :: {:ok, t()} | {:error, Changeset.t()}
  def restore(%__MODULE__{} = event) do
    event
    |> change(cancelled_at: nil)
    |> Repo.update()
  end

  # Repeats keep their wall clock time so 17:00 stays 17:00 across daylight saving
  @spec next_start(t(), DateTime.t()) :: DateTime.t()
  def next_start(%__MODULE__{repeat: :none, starts_at: starts_at}, _now), do: starts_at

  def next_start(%__MODULE__{} = event, now) do
    local = DateTime.shift_zone!(event.starts_at, event.timezone)
    skip = max(occurrences_before(event, now) - 1, 0)

    local
    |> DateTime.to_naive()
    |> step(event.repeat, skip)
    |> advance(event, now)
  end

  @spec upcoming([T.id()], DateTime.t()) :: [t()]
  def upcoming(community_ids, now) when is_list(community_ids) do
    __MODULE__
    |> where([e], e.community_id in ^community_ids)
    |> where(
      [e],
      e.repeat != :none or
        fragment("? + make_interval(mins => ?) > ?", e.starts_at, e.duration_min, ^now)
    )
    |> Repo.all()
    |> Enum.map(&%{&1 | next_starts_at: next_start(&1, now)})
    |> Enum.sort_by(&{&1.cancelled_at != nil, DateTime.to_unix(&1.next_starts_at, :microsecond)})
  end

  # Fixed periods jump to the occurrence before now and months start from an estimate
  defp occurrences_before(%__MODULE__{repeat: :monthly, starts_at: starts_at}, now) do
    div(DateTime.diff(now, starts_at, :day), 31)
  end

  defp occurrences_before(%__MODULE__{repeat: repeat, starts_at: starts_at}, now) do
    div(DateTime.diff(now, starts_at, :second), period(repeat))
  end

  defp advance(naive, event, now) do
    start = from_local(naive, event.timezone)
    ends = DateTime.add(start, event.duration_min, :minute)

    case DateTime.after?(ends, now) do
      true -> start
      false -> naive |> step(event.repeat, 1) |> advance(event, now)
    end
  end

  defp step(naive, :monthly, n) do
    date =
      naive
      |> NaiveDateTime.to_date()
      |> Date.shift(month: n)

    NaiveDateTime.new!(date, NaiveDateTime.to_time(naive))
  end

  defp step(naive, repeat, n), do: NaiveDateTime.add(naive, period(repeat) * n, :second)

  defp period(:daily), do: 86_400
  defp period(:weekly), do: 7 * 86_400
  defp period(:biweekly), do: 14 * 86_400

  # A wall clock time skipped by a clock change moves to just after it, and one that happens twice uses the first
  defp from_local(naive, timezone) do
    case DateTime.from_naive(naive, timezone) do
      {:ok, datetime} -> DateTime.shift_zone!(datetime, "Etc/UTC")
      {:gap, _before, after_gap} -> DateTime.shift_zone!(after_gap, "Etc/UTC")
      {:ambiguous, first, _second} -> DateTime.shift_zone!(first, "Etc/UTC")
    end
  end

  # A new event may start up to a minute ago so scheduling right at now works
  defp validate_future(%Changeset{data: %{__meta__: %{state: :built}}} = changeset) do
    validate_change(changeset, :starts_at, fn :starts_at, starts_at ->
      case DateTime.diff(DateTime.utc_now(), starts_at) > 60 do
        true -> [starts_at: "has already passed"]
        false -> []
      end
    end)
  end

  defp validate_future(changeset), do: changeset

  defp known_zone(:timezone, timezone) do
    case DateTime.shift_zone(DateTime.utc_now(), timezone) do
      {:ok, _datetime} -> []
      {:error, _reason} -> [timezone: "is not a known time zone"]
    end
  end

  defp validate_place(changeset) do
    case get_field(changeset, :place) do
      :room ->
        changeset
        |> validate_required([:room_id])
        |> put_change(:url, nil)

      :link ->
        changeset
        |> validate_required([:url])
        |> validate_change(:url, &web_address/2)
        |> put_change(:room_id, nil)
        |> put_change(:talk_mode, nil)

      nil ->
        changeset
    end
  end

  defp web_address(:url, url) do
    case URI.new(url) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ~w[http https] and host not in [nil, ""] ->
        []

      _other ->
        [url: "must be a web address"]
    end
  end

  @spec sitemap_entries(T.id()) :: [map()]
  def sitemap_entries(community_id) do
    __MODULE__
    |> where([e], e.community_id == ^community_id and is_nil(e.cancelled_at))
    |> order_by(asc: :starts_at, asc: :id)
    |> select([e], %{id: e.id, title: e.title, updated_at: e.updated_at})
    |> Repo.all()
  end

  @spec sitemap_counts([T.id()]) :: %{T.id() => non_neg_integer()}
  def sitemap_counts(community_ids) do
    __MODULE__
    |> where([e], e.community_id in ^community_ids and is_nil(e.cancelled_at))
    |> group_by([e], e.community_id)
    |> select([e], {e.community_id, count(e.id)})
    |> Repo.all()
    |> Map.new()
  end
end
