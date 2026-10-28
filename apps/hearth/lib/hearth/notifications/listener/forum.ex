defmodule Hearth.Notifications.Listener.Forum do
  use GenServer

  alias Hearth.Accounts
  alias Hearth.Communities
  alias Hearth.Forum
  alias Hearth.Forum.AnswerMarked
  alias Hearth.Forum.PostCreated
  alias Hearth.Forum.ReplyCreated
  alias Hearth.Notifications
  alias Hearth.Notifications.Mentions
  alias Hearth.Notifications.Notices

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], hibernate_after: 5_000)
  end

  @impl GenServer
  def init(_opts) do
    :ok = Forum.subscribe_to_pubsub()

    {:ok, nil}
  end

  # Tells the replied to author or the post's author then the mentioned then the watchers
  # Nobody hears twice about one reply
  @impl GenServer
  def handle_info(%ReplyCreated{} = event, state) do
    with {:ok, actor} <- Accounts.get_user(id: event.author_id),
         {:ok, post} <- Forum.get_post(id: event.post_id),
         {:ok, reply} <- Forum.get_reply(event.reply_id),
         {:ok, community} <- Communities.get_community(id: event.community_id) do
      recipient_id = event.parent_author_id || event.post_author_id
      notice = Notices.reply(%{actor: actor, community: community, post: post, reply: reply})

      if recipient_id != actor.id, do: tell(recipient_id, notice)

      mentioned =
        Mentions.notify(
          %{
            actor: actor,
            community: community,
            body: reply.body,
            subject: {"reply", reply.id},
            data: %{post_id: post.id, post_title: post.title, reply_id: reply.id},
            url: Notices.reply_url(community, post, reply.id)
          },
          [recipient_id]
        )

      (Forum.watcher_ids(post.id) -- [actor.id, recipient_id | mentioned])
      |> Accounts.list_users()
      |> Enum.filter(&(Communities.readable?(community, &1) and Forum.visible?(&1, post)))
      |> Enum.each(&Notifications.send(&1, notice))
    end

    {:noreply, state}
  end

  def handle_info(%PostCreated{} = event, state) do
    with {:ok, actor} <- Accounts.get_user(id: event.author_id),
         {:ok, post} <- Forum.get_post(id: event.post_id),
         {:ok, community} <- Communities.get_community(id: event.community_id) do
      Mentions.notify(%{
        actor: actor,
        community: community,
        body: post.body,
        subject: {"post", post.id},
        data: %{post_id: post.id, post_title: post.title},
        url: Notices.post_url(community, post)
      })
    end

    {:noreply, state}
  end

  def handle_info(%AnswerMarked{} = event, state) do
    with {:ok, post} <- Forum.get_post(id: event.post_id),
         true <- post.author_id != event.reply_author_id,
         {:ok, actor} <- Accounts.get_user(id: post.author_id),
         {:ok, community} <- Communities.get_community(id: post.community_id) do
      notice = %{actor: actor, community: community, post: post, reply_id: event.reply_id}

      tell(event.reply_author_id, Notices.answer(notice))
    end

    {:noreply, state}
  end

  def handle_info(_event, state), do: {:noreply, state}

  defp tell(user_id, notice) do
    with {:ok, user} <- Accounts.get_user(id: user_id), do: Notifications.send(user, notice)
  end
end
