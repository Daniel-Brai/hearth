defmodule Hearth.Moderation do
  events = [ContentRemoved, ContentRestored, ItemQueued]

  use Boundary,
    deps: [
      Hearth.Accounts,
      Hearth.Chat,
      Hearth.Common,
      Hearth.Communities,
      Hearth.Forum,
      Hearth.IAM,
      Hearth.Media,
      Hearth.PubSub,
      Hearth.Repo,
      Hearth.ScreeningPolicy
    ],
    exports: [Action, Item, Report, Screening, Subject, Verdict | events]

  alias Ecto.Changeset
  alias Hearth.Accounts
  alias Hearth.Accounts.User
  alias Hearth.Chat
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.Communities.Ban
  alias Hearth.Communities.Community
  alias Hearth.Communities.Room
  alias Hearth.IAM
  alias Hearth.Moderation.Action
  alias Hearth.Moderation.Command.BanMember
  alias Hearth.Moderation.Command.DecideItem
  alias Hearth.Moderation.Command.FileReport
  alias Hearth.Moderation.Command.HoldContent
  alias Hearth.Moderation.Command.ModerateContent
  alias Hearth.Moderation.Command.ScreenContent
  alias Hearth.Moderation.Command.SetLevel
  alias Hearth.Moderation.ContentRemoved
  alias Hearth.Moderation.ContentRestored
  alias Hearth.Moderation.Item
  alias Hearth.Moderation.ItemQueued
  alias Hearth.Moderation.Report
  alias Hearth.Moderation.Screener
  alias Hearth.Moderation.Screening
  alias Hearth.Moderation.Subject
  alias Hearth.PubSub
  alias Hearth.Repo.Page

  @topic "moderation"
  @ranks %{none: 0, reports: 1, full: 2}
  @open [:public_indexed, :public]

  @type level :: :full | :reports | :none

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  # A room can only turn its community's level down
  @spec level(Community.t(), nil | Room.t()) :: level()
  defdelegate level(community, room), to: Communities, as: :moderation_level

  @spec set_level(User.t(), Community.t() | Room.t(), nil | level()) ::
          {:ok, Community.t() | Room.t()}
          | {:error, :forbidden | :above_community | :not_found | Changeset.t()}
  def set_level(%User{} = user, %Community{} = community, level)
      when is_map_key(@ranks, level) do
    with :ok <- authorize(user, :update, :community, community.id),
         do: SetLevel.execute(user, community, level)
  end

  def set_level(%User{} = user, %Room{} = room, level)
      when is_nil(level) or is_map_key(@ranks, level) do
    with :ok <- authorize(user, :update, :room, room.community_id),
         {:ok, community} <- Communities.get_community(id: room.community_id),
         :ok <- within(community, level) do
      SetLevel.execute(user, room, level)
    end
  end

  @spec report(User.t(), Subject.type(), T.id(), map()) ::
          {:ok, Item.t()}
          | {:error, :not_found | :own | :reports_off | :already_reported | Changeset.t()}
  def report(%User{} = user, type, id, %{} = params) when is_binary(id) do
    with {:ok, subject} <- Subject.load(type, id),
         :ok <- may_read(user, subject),
         true <- subject.author_id != user.id,
         :ok <- reports_on(subject),
         {:ok, item, new?} <- FileReport.execute(user, subject, params) do
      if new?, do: broadcast(queued(item, user.id))
      {:ok, item}
    else
      false -> {:error, :own}
      error -> error
    end
  end

  @spec hold(Subject.type(), T.id(), map()) ::
          {:ok, Item.t()} | {:error, :not_found | :not_full | Changeset.t()}
  def hold(type, id, %{} = params) when is_binary(id) do
    with {:ok, subject} <- Subject.load(type, id),
         :ok <- full?(subject),
         {:ok, item} <- HoldContent.execute(subject, :automatic, params) do
      broadcast(queued(item, nil))
      {:ok, item}
    end
  end

  # Outside full, only images are looked at, and a hold goes to the instance admins
  @spec screen(Subject.type(), T.id()) ::
          {:ok, :skipped | :passed} | {:ok, Item.t()} | {:error, term()}
  def screen(type, id) when is_binary(id) do
    with true <- Screener.enabled?(),
         {:ok, %Subject{} = subject} <- screenable(type, id),
         {:ok, level} <- place_level(subject),
         {:ok, %{} = plan} <- screening_plan(level) do
      case ScreenContent.execute(subject, plan) do
        {:ok, %Item{} = item} ->
          broadcast(queued(item, nil))
          {:ok, item}

        other ->
          other
      end
    else
      false -> {:ok, :skipped}
      other -> other
    end
  end

  @spec servings() :: [Supervisor.child_spec() | module()]
  def servings do
    case Screener.impl() do
      Screener.Local -> [Screener.Local]
      _hosted_or_off -> []
    end
  end

  @spec screening() :: %{enabled: boolean(), image_floor: boolean()}
  def screening, do: %{enabled: Screener.enabled?(), image_floor: Screener.image_floor?()}

  @spec screening_summary(User.t(), pos_integer()) ::
          {:ok, %{threshold: float(), days: [Screening.day()]}} | {:error, :forbidden}
  def screening_summary(user, days \\ 30)

  def screening_summary(%User{is_instance_admin: true}, days) when days in 1..365 do
    {:ok, %{threshold: Screener.threshold(), days: Screening.daily(days)}}
  end

  def screening_summary(%User{}, _days), do: {:error, :forbidden}

  defp screenable(type, id) do
    case Subject.load(type, id) do
      {:ok, %Subject{content: %{status: :published} = content} = subject} ->
        if Map.get(content, :deleted_at), do: {:ok, :skipped}, else: {:ok, subject}

      _gone_or_decided ->
        {:ok, :skipped}
    end
  end

  defp screening_plan(:full), do: {:ok, %{text: true, images: true, queue: :automatic}}

  defp screening_plan(_level) do
    case Screener.image_floor?() do
      true -> {:ok, %{text: false, images: true, queue: :instance}}
      false -> {:ok, :skipped}
    end
  end

  @spec in_review(Subject.type(), [T.id()]) :: MapSet.t(T.id())
  def in_review(type, ids) when is_list(ids),
    do: type |> Item.pending_subjects(ids) |> MapSet.new()

  @spec reported_by(nil | User.t(), Subject.type(), [T.id()]) :: MapSet.t(T.id())
  def reported_by(nil, _type, _ids), do: MapSet.new()

  def reported_by(%User{id: id}, type, ids) when is_list(ids),
    do: id |> Report.open_subjects(type, ids) |> MapSet.new()

  @spec list_queue(User.t(), Community.t(), keyword()) ::
          {:ok, Page.t()} | {:error, :forbidden | Flop.Meta.t()}
  def list_queue(%User{} = user, %Community{id: id}, opts \\ []) when is_list(opts) do
    with :ok <- authorize(user, :remove, :content, id) do
      opts
      |> Keyword.put_new(:status, :pending)
      |> Keyword.put(:community_id, id)
      |> Keyword.put(:outside_rooms, Communities.hidden_room_ids(user, [id]))
      |> paginate()
    end
  end

  @spec list_instance_queue(User.t(), keyword()) ::
          {:ok, Page.t()} | {:error, :forbidden | Flop.Meta.t()}
  def list_instance_queue(%User{is_instance_admin: true}, opts) when is_list(opts) do
    opts
    |> Keyword.put_new(:status, :pending)
    |> Keyword.put(:source, :instance)
    |> paginate()
  end

  def list_instance_queue(%User{}, _opts), do: {:error, :forbidden}

  @spec queue_counts(User.t()) :: %{T.id() => non_neg_integer()}
  def queue_counts(%User{} = user) do
    community_ids =
      user
      |> IAM.community_ids()
      |> Enum.filter(&IAM.can?(user, :remove, %{type: :content, community_id: &1}))

    Item.pending_counts(community_ids, Communities.hidden_room_ids(user, community_ids))
  end

  @spec get_item(T.id()) :: {:ok, Item.t()} | {:error, :not_found}
  def get_item(id) when is_binary(id) do
    case Item.get(id: id) do
      nil -> {:error, :not_found}
      %Item{} = item -> {:ok, item}
    end
  end

  @spec subjects([Item.t()]) :: %{T.id() => Subject.t()}
  def subjects(items) when is_list(items) do
    for item <- items,
        {:ok, subject} <- [Subject.load(item.subject_type, item.subject_id)],
        into: %{},
        do: {item.id, subject}
  end

  @spec reports([Item.t()]) :: %{T.id() => [Report.t()]}
  def reports(items) when is_list(items), do: items |> Enum.map(& &1.id) |> Report.for_items()

  @spec keep(User.t(), Item.t(), nil | String.t()) :: decision()
  def keep(%User{} = user, %Item{} = item, reason \\ nil), do: decide(user, item, :keep, reason)

  @spec remove(User.t(), Item.t(), String.t()) :: decision()
  def remove(%User{} = user, %Item{} = item, reason) do
    with {:ok, reason} <- reason(reason), do: decide(user, item, :remove, reason)
  end

  @spec undo(User.t(), Item.t()) :: decision()
  def undo(%User{} = user, %Item{} = item), do: decide(user, item, :undo, nil)

  @spec ban_author(User.t(), Item.t(), map()) ::
          {:ok, Ban.t()}
          | {:error,
             :forbidden
             | :not_found
             | :reason_required
             | :invalid_transition
             | :stale
             | Changeset.t()}
  def ban_author(%User{} = user, %Item{community_id: community_id} = item, %{} = params)
      when is_binary(community_id) do
    with {:ok, reason} <- reason(params[:reason]),
         :ok <- authorize(user, :ban, :member, community_id),
         {:ok, _item} <- remove(user, item, reason),
         {:ok, community} <- Communities.get_community(id: community_id),
         {:ok, author} <- Accounts.get_user(id: item.author_id) do
      ban(user, community, author, params)
    end
  end

  def ban_author(%User{}, %Item{}, %{}), do: {:error, :forbidden}

  # One waiting in the queue is decided there so its item closes too
  @spec remove_content(User.t(), Subject.type(), T.id(), String.t()) ::
          {:ok, Subject.t()}
          | {:error, :forbidden | :not_found | :reason_required | Changeset.t()}
  def remove_content(%User{} = user, type, id, reason) when is_binary(id) do
    with {:ok, reason} <- reason(reason),
         {:ok, subject} <- Subject.load(type, id),
         :ok <- may_moderate(user, subject),
         {:ok, subject} <- remove_subject(user, subject, reason) do
      broadcast(removed(subject))
      {:ok, subject}
    end
  end

  # Content a queue item removed goes back through that item's undo so the queue still agrees
  @spec restore_content(User.t(), Subject.type(), T.id()) ::
          {:ok, Subject.t()} | {:error, :forbidden | :not_found | :not_removed | Changeset.t()}
  def restore_content(%User{} = user, type, id) when is_binary(id) do
    with {:ok, subject} <- Subject.load(type, id),
         :ok <- may_moderate(user, subject),
         true <- subject.content.status == :removed,
         {:ok, subject} <- restore_subject(user, subject) do
      broadcast(restored(subject))
      {:ok, subject}
    else
      false -> {:error, :not_removed}
      error -> error
    end
  end

  @spec ban(User.t(), Community.t(), User.t(), map()) ::
          {:ok, Ban.t()} | {:error, :forbidden | :reason_required | Changeset.t()}
  def ban(%User{} = user, %Community{} = community, %User{} = target, %{} = params) do
    with {:ok, reason} <- reason(params[:reason]) do
      BanMember.execute(user, community, target, Map.put(params, :reason, reason))
    end
  end

  @spec ban_username(User.t(), Community.t(), String.t(), map()) ::
          {:ok, Ban.t()} | {:error, :forbidden | :not_found | :reason_required | Changeset.t()}
  def ban_username(%User{} = user, %Community{} = community, username, %{} = params)
      when is_binary(username) do
    with {:ok, target} <- Accounts.get_user(username: String.trim_leading(username, "@")) do
      ban(user, community, target, params)
    end
  end

  @spec lift_ban(User.t(), Ban.t(), nil | String.t()) ::
          {:ok, Ban.t()} | {:error, :forbidden | Changeset.t()}
  def lift_ban(%User{} = user, %Ban{} = ban, reason \\ nil),
    do: BanMember.lift(user, ban, blank_to_nil(reason))

  @spec list_bans(User.t(), Community.t()) :: {:ok, [Ban.t()]} | {:error, :forbidden}
  def list_bans(%User{} = user, %Community{} = community) do
    with :ok <- authorize(user, :ban, :member, community.id),
         do: {:ok, Communities.list_bans(community)}
  end

  # Callers check that the viewer can see the community
  @spec list_log(Community.t(), keyword()) :: Page.t() | {:error, Flop.Meta.t()}
  def list_log(%Community{id: id}, opts \\ []) when is_list(opts) do
    opts
    |> Keyword.put(:community_id, id)
    |> Action.paginate()
  end

  defp decide(user, item, event, reason) do
    with :ok <- may_decide(user, item),
         subject = subject_or_nil(item),
         {:ok, decided} <- DecideItem.execute(user, item, subject, event, reason) do
      announce(item, decided, subject)
      {:ok, decided}
    end
  end

  @typep decision ::
           {:ok, Item.t()}
           | {:error,
              :forbidden | :reason_required | :invalid_transition | :stale | Changeset.t()}

  defp subject_or_nil(item) do
    case Subject.load(item.subject_type, item.subject_id) do
      {:ok, subject} -> subject
      {:error, :not_found} -> nil
    end
  end

  defp announce(_item, _decided, nil), do: :ok
  defp announce(_item, %Item{status: :removed}, subject), do: broadcast(removed(subject))

  defp announce(%Item{status: :removed}, %Item{status: :pending}, subject),
    do: broadcast(restored(subject))

  defp announce(_item, _decided, _subject), do: :ok

  defp restore_subject(user, subject) do
    case Item.last_removal(subject.type, subject.content.id) do
      %Item{} = item ->
        with {:ok, _item} <- DecideItem.execute(user, item, subject, :undo, nil),
             do: {:ok, %{subject | content: %{subject.content | status: :published}}}

      nil ->
        ModerateContent.execute(user, subject, :published, nil)
    end
  end

  defp remove_subject(user, subject, reason) do
    case Item.pending(subject.type, subject.content.id) do
      %Item{} = item ->
        with {:ok, _item} <- DecideItem.execute(user, item, subject, :remove, reason),
             do: {:ok, %{subject | content: %{subject.content | status: :removed}}}

      nil ->
        ModerateContent.execute(user, subject, :removed, reason)
    end
  end

  defp paginate(opts) do
    case Item.paginate(opts) do
      %Page{} = page -> {:ok, page}
      {:error, _meta} = error -> error
    end
  end

  defp reports_on(%Subject{community_id: nil}), do: :ok

  defp reports_on(%Subject{} = subject) do
    case place_level(subject) do
      {:ok, :none} -> {:error, :reports_off}
      {:ok, _level} -> :ok
      error -> error
    end
  end

  defp full?(subject) do
    case place_level(subject) do
      {:ok, :full} -> :ok
      {:ok, _level} -> {:error, :not_full}
      error -> error
    end
  end

  defp place_level(%Subject{community_id: community_id, room_id: room_id}) do
    level_at(community_id, room_id)
  end

  defp level_at(nil, _room_id), do: {:ok, :none}

  defp level_at(community_id, room_id) do
    with {:ok, community} <- Communities.get_community(id: community_id),
         {:ok, room} <- room(room_id) do
      {:ok, level(community, room)}
    end
  end

  defp room(nil), do: {:ok, nil}
  defp room(id), do: Communities.get_room(id: id)

  # Only content the reporter can read can be reported, and nothing removed
  defp may_read(_user, %Subject{content: %{status: :removed}}), do: {:error, :not_found}

  defp may_read(user, %Subject{type: :message} = subject) do
    with {:ok, place} <- message_place(user, subject) do
      if Chat.can_read?(user, place), do: :ok, else: {:error, :not_found}
    end
  end

  defp may_read(user, %Subject{community_id: community_id}) do
    with {:ok, community} <- Communities.get_community(id: community_id) do
      if community.visibility in @open or IAM.member?(user, community.id),
        do: :ok,
        else: {:error, :not_found}
    end
  end

  defp message_place(user, %Subject{room_id: nil, conversation_id: id}),
    do: Chat.get_conversation(user, id)

  defp message_place(_user, %Subject{room_id: id}), do: Communities.get_room(id: id)

  defp may_moderate(%User{is_instance_admin: true}, %Subject{community_id: nil}), do: :ok
  defp may_moderate(%User{}, %Subject{community_id: nil}), do: {:error, :forbidden}

  defp may_moderate(user, %Subject{community_id: id} = subject) do
    with :ok <- authorize(user, :remove, :content, id), do: sees_room(user, id, subject.room_id)
  end

  defp may_decide(%User{is_instance_admin: true}, %Item{community_id: nil}), do: :ok
  defp may_decide(%User{}, %Item{community_id: nil}), do: {:error, :forbidden}

  defp may_decide(user, %Item{community_id: id} = item) do
    with :ok <- authorize(user, :remove, :content, id), do: sees_room(user, id, item.room_id)
  end

  defp sees_room(_user, _community_id, nil), do: :ok

  defp sees_room(user, community_id, room_id) do
    case room_id in Communities.hidden_room_ids(user, [community_id]) do
      true -> {:error, :not_found}
      false -> :ok
    end
  end

  defp within(_community, nil), do: :ok

  defp within(%Community{moderation: community}, level) do
    case @ranks[level] <= @ranks[community] do
      true -> :ok
      false -> {:error, :above_community}
    end
  end

  defp reason(reason) do
    case blank_to_nil(reason) do
      nil -> {:error, :reason_required}
      reason -> {:ok, reason}
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(text) when is_binary(text) do
    case String.trim(text) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp queued(item, reporter_id) do
    %ItemQueued{
      item_id: item.id,
      community_id: item.community_id,
      source: item.source,
      subject_type: item.subject_type,
      subject_id: item.subject_id,
      author_id: item.author_id,
      reporter_id: reporter_id
    }
  end

  defp removed(subject), do: struct!(ContentRemoved, place_fields(subject))
  defp restored(subject), do: struct!(ContentRestored, place_fields(subject))

  defp place_fields(subject) do
    %{
      subject_type: subject.type,
      subject_id: subject.content.id,
      community_id: subject.community_id,
      room_id: subject.room_id,
      post_id: subject.post_id,
      conversation_id: subject.conversation_id
    }
  end

  defp authorize(user, action, type, community_id) do
    case IAM.can?(user, action, %{type: type, community_id: community_id}) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp broadcast(event), do: PubSub.broadcast(@topic, event)
end
