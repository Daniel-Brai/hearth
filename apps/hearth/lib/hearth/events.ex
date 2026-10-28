defmodule Hearth.Events do
  events = [EventCancelled, EventReminder, EventScheduled, EventUpdated]

  default = [Event | events]

  exports =
    case Mix.env() do
      :test -> [Interest | default]
      _env -> default
    end

  use Boundary,
    deps: [
      Hearth.Accounts,
      Hearth.Common,
      Hearth.Communities,
      Hearth.IAM,
      Hearth.PubSub,
      Hearth.Repo
    ],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias Hearth.Events.Command.ScheduleEvent
  alias Hearth.Events.Event
  alias Hearth.Events.EventCancelled
  alias Hearth.Events.EventLibrary
  alias Hearth.Events.EventScheduled
  alias Hearth.Events.EventUpdated
  alias Hearth.Events.Interest
  alias Hearth.Events.VoiceStart
  alias Hearth.Events.Worker.Remind
  alias Hearth.IAM
  alias Hearth.PubSub

  @topic "events"

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec template_event(String.t()) :: nil | map()
  def template_event(template) when is_binary(template), do: EventLibrary.for_template(template)

  @spec broadcast_to_pubsub(struct()) :: :ok
  def broadcast_to_pubsub(event), do: PubSub.broadcast(@topic, event)

  @spec schedule_event(User.t(), Community.t(), map(), keyword()) ::
          {:ok, Event.t()} | {:error, :forbidden | :not_found | Changeset.t()}
  def schedule_event(%User{} = user, %Community{} = community, %{} = params, opts \\ []) do
    with :ok <- authorize(user, community.id, nil),
         {:ok, params} <- with_room(community.id, params),
         {:ok, event} <- ScheduleEvent.execute(user, community.id, params) do
      broadcast_to_pubsub(%EventScheduled{
        event_id: event.id,
        community_id: community.id,
        host_id: user.id,
        notify: Keyword.get(opts, :notify, false)
      })

      {:ok, event}
    end
  end

  @spec update_event(User.t(), Event.t(), map()) ::
          {:ok, Event.t()} | {:error, :forbidden | :not_found | Changeset.t()}
  def update_event(%User{} = user, %Event{} = event, %{} = params) do
    with :ok <- authorize(user, event.community_id, event.host_id),
         {:ok, params} <- with_room(event.community_id, params),
         {:ok, updated} <- Event.update(event, params) do
      moved? = updated.starts_at != event.starts_at or updated.repeat != event.repeat
      if moved?, do: Remind.schedule(updated)
      if moved? or updated.room_id != event.room_id, do: VoiceStart.schedule(updated)

      broadcast_to_pubsub(%EventUpdated{
        event_id: updated.id,
        community_id: updated.community_id,
        moved: moved?
      })

      {:ok, updated}
    end
  end

  @spec cancel_event(User.t(), Event.t()) ::
          {:ok, Event.t()} | {:error, :forbidden | Changeset.t()}
  def cancel_event(%User{} = user, %Event{} = event) do
    with :ok <- authorize(user, event.community_id, event.host_id),
         {:ok, event} <- Event.cancel(event) do
      broadcast_to_pubsub(%EventCancelled{
        event_id: event.id,
        community_id: event.community_id,
        cancelled_by_id: user.id
      })

      {:ok, event}
    end
  end

  @spec restore_event(User.t(), Event.t()) ::
          {:ok, Event.t()} | {:error, :forbidden | Changeset.t()}
  def restore_event(%User{} = user, %Event{} = event) do
    with :ok <- authorize(user, event.community_id, event.host_id),
         {:ok, event} <- Event.restore(event) do
      Remind.schedule(event)
      VoiceStart.schedule(event)
      {:ok, event}
    end
  end

  @spec delete_event(User.t(), Event.t()) ::
          {:ok, Event.t()} | {:error, :forbidden | Changeset.t()}
  def delete_event(%User{} = user, %Event{} = event) do
    with :ok <- authorize(user, event.community_id, event.host_id) do
      if is_nil(event.cancelled_at) do
        broadcast_to_pubsub(%EventCancelled{
          event_id: event.id,
          community_id: event.community_id,
          cancelled_by_id: user.id
        })
      end

      Event.delete(event)
    end
  end

  @spec toggle_interest(User.t(), Event.t()) ::
          {:ok, :interested | :not_interested} | {:error, :forbidden}
  def toggle_interest(%User{} = user, %Event{} = event) do
    case IAM.member?(user, event.community_id) do
      true -> {:ok, Interest.toggle(event.id, user.id)}
      false -> {:error, :forbidden}
    end
  end

  @spec queue_voice_start(Event.t(), DateTime.t()) :: :ok
  def queue_voice_start(%Event{} = event, from), do: VoiceStart.schedule(event, from)

  @spec get_event(keyword()) :: {:ok, Event.t()} | {:error, :not_found}
  def get_event(opts) when is_list(opts) do
    case Event.get(opts) do
      nil -> {:error, :not_found}
      %Event{} = event -> {:ok, event}
    end
  end

  @spec list_upcoming([T.id()], DateTime.t()) :: [Event.t()]
  def list_upcoming(community_ids, now \\ DateTime.utc_now()) when is_list(community_ids) do
    Event.upcoming(community_ids, now)
  end

  @spec happening_in(T.id(), T.id(), DateTime.t()) :: nil | Event.t()
  def happening_in(community_id, room_id, now \\ DateTime.utc_now()) do
    [community_id]
    |> list_upcoming(now)
    |> Enum.find(
      &(&1.room_id == room_id and &1.cancelled_at == nil and
          not DateTime.after?(&1.next_starts_at, now))
    )
  end

  @spec interested_ids([Event.t()]) :: %{T.id() => [T.id()]}
  def interested_ids(events) when is_list(events),
    do: events |> Enum.map(& &1.id) |> Interest.user_ids_by_event()

  @spec sitemap_events(T.id()) :: [%{id: T.id(), title: String.t(), updated_at: DateTime.t()}]
  def sitemap_events(community_id), do: Event.sitemap_entries(community_id)

  @spec count_sitemap_events([T.id()]) :: %{T.id() => non_neg_integer()}
  def count_sitemap_events(community_ids) when is_list(community_ids),
    do: Event.sitemap_counts(community_ids)

  @spec create_template_event(T.id(), String.t()) :: {:ok, nil | Event.t()} | {:error, term()}
  def create_template_event(community_id, template) do
    with %{} = spec <- EventLibrary.for_template(template),
         {:ok, community} <- Communities.get_community(id: community_id),
         {:ok, owner} <- Accounts.get_user(id: community.owner_id),
         %{} = room <- voice_room(community) do
      timezone = owner.timezone || "Etc/UTC"

      params = %{
        title: spec.title,
        starts_at: at_five(spec.days, timezone),
        duration_min: spec.mins,
        repeat: spec.repeat,
        timezone: timezone,
        place: :room,
        room_id: room.id,
        talk_mode: :stage
      }

      ScheduleEvent.execute(owner, community.id, params)
    else
      nil -> {:ok, nil}
      error -> error
    end
  end

  defp voice_room(community) do
    community
    |> Communities.list_rooms()
    |> Enum.find(&(&1.type == :voice))
  end

  defp at_five(days, timezone) do
    date = Date.add(Date.utc_today(), days)

    case DateTime.new(date, ~T[17:00:00], timezone) do
      {:ok, datetime} -> DateTime.shift_zone!(datetime, "Etc/UTC")
      {:gap, _before, after_gap} -> DateTime.shift_zone!(after_gap, "Etc/UTC")
      {:ambiguous, first, _second} -> DateTime.shift_zone!(first, "Etc/UTC")
      {:error, _reason} -> DateTime.new!(date, ~T[17:00:00])
    end
  end

  # Voice rooms default to Stage, and chat rooms have no talk mode
  defp with_room(community_id, params) do
    room_id = params[:room_id] || params["room_id"]

    room = if room_id, do: Communities.get_room(id: room_id, community_id: community_id)

    case room do
      nil -> {:ok, params}
      {:ok, %{type: :voice}} -> {:ok, Map.put_new(params, :talk_mode, :open)}
      {:ok, %{}} -> {:ok, Map.put(params, :talk_mode, nil)}
      {:error, :not_found} -> {:error, :not_found}
    end
  end

  defp authorize(user, community_id, host_id) do
    object = %{type: :event, community_id: community_id, author_id: host_id}

    case IAM.can?(user, :create, object) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end
end
