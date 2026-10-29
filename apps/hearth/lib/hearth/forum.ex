defmodule Hearth.Forum do
  events = [AnswerMarked, KindsChanged, PostCreated, ReplyCreated]

  default = [Draft, Kind, Post, Reply | events]

  exports =
    case Mix.env() do
      :test -> default ++ [HelpfulMark, PostReacted, PostRead, PostWatch, Tag]
      _env -> default
    end

  use Boundary,
    deps: [
      Hearth.Accounts,
      Hearth.Buffer,
      Hearth.Chat,
      Hearth.Common,
      Hearth.Communities,
      Hearth.IAM,
      Hearth.Media,
      Hearth.PubSub,
      Hearth.Repo,
      Hearth.ScreeningPolicy
    ],
    exports: exports

  alias Ecto.Changeset
  alias Hearth.Accounts.User
  alias Hearth.Buffer
  alias Hearth.Chat
  alias Hearth.Common.T
  alias Hearth.Communities
  alias Hearth.Communities.Community
  alias Hearth.Communities.Room
  alias Hearth.Forum.AnswerMarked
  alias Hearth.Forum.Command.CreateDefaultKinds
  alias Hearth.Forum.Command.CreatePost
  alias Hearth.Forum.Command.CreateReply
  alias Hearth.Forum.Command.DeleteReply
  alias Hearth.Forum.Command.EditReply
  alias Hearth.Forum.Command.PromoteMessages
  alias Hearth.Forum.Command.SaveKinds
  alias Hearth.Forum.Command.ToggleHelpful
  alias Hearth.Forum.Command.UpdatePost
  alias Hearth.Forum.Draft
  alias Hearth.Forum.HelpfulMark
  alias Hearth.Forum.Kind
  alias Hearth.Forum.KindLibrary
  alias Hearth.Forum.KindsChanged
  alias Hearth.Forum.Post
  alias Hearth.Forum.PostCreated
  alias Hearth.Forum.PostReacted
  alias Hearth.Forum.PostReaction
  alias Hearth.Forum.PostRead
  alias Hearth.Forum.PostWatch
  alias Hearth.Forum.Reads
  alias Hearth.Forum.Reply
  alias Hearth.Forum.ReplyCreated
  alias Hearth.IAM
  alias Hearth.PubSub
  alias Hearth.Repo.Page

  @topic "forum"

  @spec subscribe_to_pubsub() :: :ok
  def subscribe_to_pubsub, do: PubSub.subscribe(@topic)

  @spec create_default_kinds(T.id(), String.t()) :: {:ok, [Kind.t()]} | {:error, Changeset.t()}
  def create_default_kinds(community_id, template) when is_binary(community_id) do
    CreateDefaultKinds.execute(community_id, template)
  end

  @spec template_kinds(String.t()) :: [String.t()]
  def template_kinds(template) when is_binary(template),
    do: KindLibrary.keys_for_template(template)

  @spec list_kinds(T.id()) :: [Kind.t()]
  def list_kinds(community_id) when is_binary(community_id) do
    Kind.for_community(community_id)
  end

  @spec save_kinds(User.t(), Community.t(), [map()]) ::
          {:ok, [Kind.t()]}
          | {:error, :forbidden | :keeps_discussion | :no_discussion | Changeset.t()}
  def save_kinds(%User{} = user, %Community{} = community, kinds) when is_list(kinds) do
    with :ok <- authorize(user, :update, :community, community.id),
         {:ok, saved} <- SaveKinds.execute(community.id, kinds) do
      broadcast(%KindsChanged{community_id: community.id})
      {:ok, saved}
    end
  end

  @spec create_post(User.t(), Community.t(), map()) ::
          {:ok, Post.t()}
          | {:error,
             :forbidden
             | :unknown_kind
             | :too_many_attachments
             | :invalid_attachment
             | Changeset.t()}
  def create_post(%User{} = user, %Community{} = community, %{} = params) do
    kind_id = params[:kind_id] || params["kind_id"]

    with :ok <- authorize(user, :create, :post, community.id),
         {:ok, kind} <- fetch_kind(community.id, kind_id),
         :ok <- may_use_kind(user, community.id, kind),
         {:ok, post} <- CreatePost.execute(user, community, params) do
      broadcast(%PostCreated{post_id: post.id, community_id: community.id, author_id: user.id})
      {:ok, post}
    end
  end

  # The first message becomes the post and the rest its replies, each under the person who wrote it.
  # A private room's messages stay in it, since a post shows to everyone
  @spec promote(User.t(), Room.t(), [T.id()], map()) ::
          {:ok, Post.t()}
          | {:error,
             :forbidden | :private_room | :unknown_kind | :invalid_messages | Changeset.t()}
  def promote(%User{} = user, %Room{} = room, message_ids, %{} = params) do
    kind_id = params[:kind_id] || params["kind_id"]

    with :ok <- authorize(user, :promote, :chat, room.community_id),
         :ok <- open_room(room),
         {:ok, messages} <- Chat.get_promotable(room, message_ids),
         {:ok, community} <- Communities.get_community(id: room.community_id),
         {:ok, kind} <- fetch_kind(community.id, kind_id),
         :ok <- may_use_kind(user, community.id, kind),
         {:ok, post} <- PromoteMessages.execute(user, community, room, messages, params) do
      broadcast(%PostCreated{
        post_id: post.id,
        community_id: community.id,
        author_id: post.author_id
      })

      {:ok, _notice} = Chat.note_promoted(user, room, post)
      {:ok, post}
    end
  end

  defp open_room(%Room{access: :everyone}), do: :ok
  defp open_room(%Room{}), do: {:error, :private_room}

  @spec get_post(keyword()) :: {:ok, Post.t()} | {:error, :not_found}
  def get_post(opts) when is_list(opts) do
    opts = Keyword.put_new(opts, :deleted_at, nil)

    case Post.get(opts) do
      nil -> {:error, :not_found}
      %Post{} = post -> {:ok, post}
    end
  end

  # Held or removed posts show only to their author and to moderators
  @spec visible?(nil | User.t(), Post.t()) :: boolean()
  def visible?(_viewer, %Post{status: :published}), do: true
  def visible?(nil, %Post{}), do: false
  def visible?(%User{id: id}, %Post{author_id: id}), do: true
  def visible?(%User{} = viewer, %Post{} = post), do: moderator?(viewer, post.community_id)

  # Skips authorization so only Hearth.Moderation calls it
  @spec moderate(Post.t() | Reply.t(), :published | :pending | :removed) ::
          {:ok, Post.t() | Reply.t()} | {:error, Changeset.t()}
  def moderate(%Post{} = post, status), do: Post.put_status(post, status)
  def moderate(%Reply{} = reply, status), do: Reply.put_status(reply, status)

  @spec get_reply(Hearth.Common.T.id()) :: {:ok, Reply.t()} | {:error, :not_found}
  def get_reply(id) when is_binary(id) do
    case Reply.get(id: id, deleted_at: nil) do
      nil -> {:error, :not_found}
      %Reply{} = reply -> {:ok, reply}
    end
  end

  @spec sitemap_posts(T.id(), non_neg_integer(), non_neg_integer()) ::
          [%{id: T.id(), title: String.t(), updated_at: DateTime.t()}]
  def sitemap_posts(community_id, offset, limit),
    do: Post.sitemap_entries(community_id, offset, limit)

  @spec sitemap_stats([T.id()]) :: %{T.id() => {non_neg_integer(), DateTime.t()}}
  def sitemap_stats(community_ids) when is_list(community_ids),
    do: Post.sitemap_stats(community_ids)

  @spec list_posts(Community.t(), keyword()) :: Page.t() | {:error, Flop.Meta.t()}
  def list_posts(%Community{id: id}, opts \\ []) when is_list(opts) do
    opts
    |> Keyword.merge(community_id: id, status: :published, deleted_at: nil, pinned_at: nil)
    |> Post.paginate()
  end

  # Posts and replies waiting on a report still count since they still show in feeds
  @spec author_counts(T.id(), [T.id()]) :: %{
          posts: non_neg_integer(),
          answers: non_neg_integer(),
          people_helped: non_neg_integer()
        }
  def author_counts(author_id, community_ids) when is_list(community_ids) do
    %{
      posts: Post.count_by_author(author_id, community_ids),
      answers: Reply.count_answers_by(author_id, community_ids),
      people_helped: HelpfulMark.count_people_helped(author_id, community_ids)
    }
  end

  @spec list_author_posts(T.id(), [T.id()], keyword()) :: Page.t() | {:error, Flop.Meta.t()}
  def list_author_posts(author_id, community_ids, opts \\ []) when is_list(community_ids) do
    opts
    |> Keyword.merge(author_id: author_id, community_id: community_ids)
    |> Keyword.merge(status: :published, deleted_at: nil)
    |> Keyword.merge(order_by: [:inserted_at, :id], order_directions: [:desc, :desc])
    |> Post.paginate()
  end

  @spec list_author_replies(T.id(), [T.id()], keyword()) :: Page.t() | {:error, Flop.Meta.t()}
  def list_author_replies(author_id, community_ids, opts \\ []) when is_list(community_ids) do
    opts
    |> Keyword.merge(author_id: author_id, status: :published, deleted_at: nil)
    |> Keyword.merge(in_communities: community_ids)
    |> Keyword.merge(order_by: [:inserted_at, :id], order_directions: [:desc, :desc])
    |> Reply.paginate()
  end

  @spec list_posts_by_id([T.id()]) :: %{T.id() => Post.t()}
  def list_posts_by_id(ids) when is_list(ids) do
    [id: Enum.uniq(ids)]
    |> Post.all()
    |> Map.new(&{&1.id, &1})
  end

  @spec list_pinned(Community.t()) :: [Post.t()]
  def list_pinned(%Community{id: id}) do
    Post.pinned(id)
  end

  @spec update_post(User.t(), Post.t(), map()) ::
          {:ok, Post.t()}
          | {:error, :forbidden | :too_many_attachments | :invalid_attachment | Changeset.t()}
  def update_post(%User{id: id} = user, %Post{author_id: id} = post, %{} = params) do
    UpdatePost.execute(user, post, params)
  end

  def update_post(%User{}, %Post{}, %{}), do: {:error, :forbidden}

  @spec delete_post(User.t(), Post.t()) :: {:ok, Post.t()} | {:error, :forbidden | Changeset.t()}
  def delete_post(%User{id: id}, %Post{author_id: id} = post), do: Post.delete(post)
  def delete_post(%User{}, %Post{}), do: {:error, :forbidden}

  @spec pin_post(User.t(), Post.t(), boolean()) :: {:ok, Post.t()} | {:error, :forbidden}
  def pin_post(%User{} = user, %Post{} = post, pinned?) when is_boolean(pinned?) do
    with :ok <- authorize(user, :pin, :post, post.community_id), do: Post.pin(post, pinned?)
  end

  @spec lock_post(User.t(), Post.t(), boolean()) :: {:ok, Post.t()} | {:error, :forbidden}
  def lock_post(%User{} = user, %Post{} = post, locked?) when is_boolean(locked?) do
    with :ok <- authorize(user, :remove, :content, post.community_id),
         do: Post.lock(post, locked?)
  end

  @spec reply(User.t(), Post.t(), map()) ::
          {:ok, Reply.t()}
          | {:error,
             :forbidden
             | :locked
             | :not_found
             | :pending
             | :too_many_attachments
             | :invalid_attachment
             | Changeset.t()}
  def reply(%User{} = user, %Post{} = post, %{} = params) do
    parent_id = params[:parent_reply_id] || params["parent_reply_id"]

    with :ok <- authorize(user, :create, :reply, post.community_id),
         :ok <- open?(post),
         {:ok, parent} <- fetch_parent(post, parent_id),
         {:ok, reply} <- CreateReply.execute(user, post, parent, params) do
      broadcast(%ReplyCreated{
        reply_id: reply.id,
        post_id: post.id,
        parent_reply_id: get_in(parent.id),
        community_id: post.community_id,
        author_id: user.id,
        parent_author_id: get_in(parent.author_id),
        post_author_id: post.author_id
      })

      {:ok, reply}
    end
  end

  # Replies inside a branch are oldest first so they read as a conversation
  @spec list_replies(Post.t(), keyword()) :: Page.t() | {:error, Flop.Meta.t()}
  def list_replies(%Post{id: post_id} = post, opts \\ []) when is_list(opts) do
    {viewer, opts} = Keyword.pop(opts, :viewer)
    {parent, rest} = Keyword.pop(opts, :parent)
    {sort, paging} = Keyword.pop(rest, :sort, :helpful)

    order =
      case {parent, sort} do
        {nil, :helpful} ->
          [order_by: ~w[helpful_count inserted_at id]a, order_directions: ~w[desc asc asc]a]

        {nil, :newest} ->
          [order_by: [:inserted_at, :id], order_directions: [:desc, :desc]]

        {_parent, _sort} ->
          [order_by: [:inserted_at, :id], order_directions: [:asc, :asc]]
      end

    paging
    |> Keyword.merge(order)
    |> Keyword.merge(post_id: post_id, parent_reply_id: get_in(parent.id))
    |> Keyword.put(:visible_to, viewing(viewer, post.community_id))
    |> Reply.paginate()
  end

  @spec update_reply(User.t(), Reply.t(), map()) ::
          {:ok, Reply.t()}
          | {:error, :forbidden | :too_many_attachments | :invalid_attachment | Changeset.t()}
  def update_reply(%User{id: id} = user, %Reply{author_id: id} = reply, %{} = params) do
    EditReply.execute(user, reply, params)
  end

  def update_reply(%User{}, %Reply{}, %{}), do: {:error, :forbidden}

  # A reply with answers stays as "Reply deleted" so the thread keeps its shape
  @spec delete_reply(User.t(), Reply.t()) ::
          {:ok, Reply.t()} | {:error, :forbidden | Changeset.t()}
  def delete_reply(%User{id: id}, %Reply{author_id: id, child_count: 0} = reply) do
    DeleteReply.execute(reply)
  end

  def delete_reply(%User{id: id}, %Reply{author_id: id} = reply), do: Reply.delete(reply)
  def delete_reply(%User{}, %Reply{}), do: {:error, :forbidden}

  @spec mark_answer(User.t(), Post.t(), nil | Reply.t()) ::
          {:ok, Post.t()} | {:error, :forbidden | :no_answers | :not_found}
  def mark_answer(%User{} = user, %Post{} = post, reply) do
    object = %{type: :post, community_id: post.community_id, author_id: post.author_id}

    with true <- IAM.can?(user, :answer, object),
         %Kind{answers: true} <- Kind.get(id: post.kind_id),
         :ok <- same_post(post, reply),
         {:ok, post} <- Post.set_answer(post, get_in(reply.id)) do
      if reply do
        broadcast(%AnswerMarked{
          post_id: post.id,
          reply_id: reply.id,
          reply_author_id: reply.author_id
        })
      end

      {:ok, post}
    else
      false -> {:error, :forbidden}
      nil -> {:error, :not_found}
      %Kind{} -> {:error, :no_answers}
      {:error, _reason} = error -> error
    end
  end

  @spec toggle_helpful(User.t(), Post.t() | Reply.t()) ::
          {:ok, :marked | :unmarked} | {:error, :own}
  def toggle_helpful(%User{id: id}, %{author_id: id}), do: {:error, :own}

  def toggle_helpful(%User{} = user, subject), do: ToggleHelpful.execute(user, subject)

  @spec toggle_reaction(User.t(), Post.t(), String.t()) ::
          {:ok, :added | :removed} | {:error, :invalid_emoji}
  def toggle_reaction(%User{} = user, %Post{} = post, emoji) when is_binary(emoji) do
    with :ok <- valid_emoji(emoji) do
      state = PostReaction.toggle(post.id, user.id, emoji)

      broadcast(%PostReacted{
        post_id: post.id,
        community_id: post.community_id,
        user_id: user.id,
        emoji: emoji,
        on: state == :added,
        count: PostReaction.count(post.id, emoji)
      })

      {:ok, state}
    end
  end

  @spec list_reactions(nil | User.t(), [Post.t()]) :: %{T.id() => [PostReaction.summary()]}
  def list_reactions(user, posts) when is_list(posts),
    do: posts |> Enum.map(& &1.id) |> PostReaction.summaries(get_in(user.id))

  @spec watch_post(User.t(), Post.t(), boolean()) :: :ok
  def watch_post(%User{} = user, %Post{} = post, watching) when is_boolean(watching),
    do: PostWatch.put(user.id, post.id, watching)

  @spec watched(nil | User.t(), Post.t() | [Post.t()]) :: MapSet.t(T.id())
  def watched(nil, _posts), do: MapSet.new()
  def watched(%User{} = user, %Post{} = post), do: watched(user, [post])
  def watched(%User{} = user, posts), do: PostWatch.watched(user.id, Enum.map(posts, & &1.id))

  @spec list_unread_since(User.t(), [T.id()], DateTime.t(), pos_integer()) :: [Post.t()]
  def list_unread_since(%User{} = user, community_ids, %DateTime{} = since, limit),
    do: Post.unread_since(user.id, community_ids, since, limit)

  @spec watcher_ids(T.id()) :: [T.id()]
  def watcher_ids(post_id), do: PostWatch.watcher_ids(post_id)

  @spec seen(nil | User.t(), [Post.t()]) :: MapSet.t(T.id())
  def seen(nil, _posts), do: MapSet.new()
  def seen(%User{id: id}, posts), do: PostRead.seen(id, Enum.map(posts, & &1.id))

  # Catch up's mark all as seen covers every community the person joined
  @spec mark_all_seen(User.t(), nil | Community.t()) :: :ok | {:error, :forbidden | :not_found}
  def mark_all_seen(%User{} = user, nil), do: PostRead.mark_all(user.id, IAM.community_ids(user))

  def mark_all_seen(%User{} = user, %Community{} = community) do
    case Communities.readable?(community, user) do
      true -> PostRead.mark_all(user.id, [community.id])
      false -> Communities.refusal(user, community.id)
    end
  end

  @spec mark_seen(User.t(), Post.t()) :: :ok
  def mark_seen(%User{} = user, %Post{} = post) do
    now = System.os_time(:microsecond)

    Buffer.put_newer(Reads, {user.id, post.id}, post.reply_count, now)
  end

  @spec get_draft(User.t(), Community.t()) :: nil | Draft.t()
  def get_draft(%User{id: user_id}, %Community{id: community_id}) do
    Draft.get(user_id: user_id, community_id: community_id)
  end

  @spec list_drafts(User.t()) :: [Draft.t()]
  def list_drafts(%User{id: user_id}), do: Draft.all(user_id: user_id, preload: :kind)

  @spec save_draft(User.t(), Community.t(), map()) ::
          {:ok, Draft.t()} | {:error, :forbidden | Changeset.t()}
  def save_draft(%User{} = user, %Community{} = community, %{} = params) do
    with :ok <- authorize(user, :create, :post, community.id) do
      case get_draft(user, community) do
        nil -> Draft.insert(%Draft{user_id: user.id, community_id: community.id}, params)
        %Draft{} = draft -> Draft.update(draft, params)
      end
    end
  end

  @spec discard_draft(User.t(), Community.t()) :: :ok
  def discard_draft(%User{} = user, %Community{} = community) do
    with %Draft{} = draft <- get_draft(user, community), do: Draft.delete(draft)

    :ok
  end

  defp fetch_kind(community_id, kind_id) when is_binary(kind_id) do
    case Kind.get(id: kind_id, community_id: community_id) do
      nil -> {:error, :unknown_kind}
      %Kind{} = kind -> {:ok, kind}
    end
  end

  defp fetch_kind(_community_id, _kind_id), do: {:error, :unknown_kind}

  defp may_use_kind(_user, _community_id, %Kind{postable: true}), do: :ok
  defp may_use_kind(user, community_id, %Kind{}), do: authorize(user, :pin, :post, community_id)

  defp open?(%Post{deleted_at: nil, locked_at: nil}), do: :ok
  defp open?(%Post{deleted_at: nil}), do: {:error, :locked}
  defp open?(%Post{}), do: {:error, :not_found}

  defp fetch_parent(_post, nil), do: {:ok, nil}

  defp fetch_parent(post, parent_id) do
    case Reply.get(id: parent_id, post_id: post.id, deleted_at: nil) do
      nil -> {:error, :not_found}
      %Reply{status: :pending} -> {:error, :pending}
      %Reply{} = parent -> {:ok, parent}
    end
  end

  defp same_post(_post, nil), do: :ok
  defp same_post(%Post{id: id}, %Reply{post_id: id}), do: :ok
  defp same_post(%Post{}, %Reply{}), do: {:error, :not_found}

  defp viewing(nil, _community_id), do: nil

  defp viewing(%User{id: id} = viewer, community_id) do
    case moderator?(viewer, community_id) do
      true -> :all
      false -> id
    end
  end

  defp moderator?(viewer, community_id),
    do: IAM.can?(viewer, :remove, %{type: :content, community_id: community_id})

  defp authorize(user, action, type, community_id) do
    case IAM.can?(user, action, %{type: type, community_id: community_id}) do
      true -> :ok
      false -> {:error, :forbidden}
    end
  end

  defp valid_emoji(emoji) do
    case String.length(emoji) in 1..8 and byte_size(emoji) <= 32 do
      true -> :ok
      false -> {:error, :invalid_emoji}
    end
  end

  defp broadcast(event), do: PubSub.broadcast(@topic, event)
end
