defmodule Hearth.Notifications.Notices do
  alias Hearth.Common
  alias Hearth.Common.T
  alias Hearth.Notifications
  alias Hearth.Notifications.InAppMessage
  alias Hearth.Notifications.Notice

  @excerpt 120

  @spec reply(map()) :: Notice.t()
  def reply(%{actor: actor, community: community, post: post, reply: reply}) do
    notice(:reply, "replies", %{
      actor: actor,
      community: community,
      subject: {"reply", reply.id},
      data: %{post_id: post.id, post_title: post.title, reply_id: reply.id},
      title: "#{name(actor)} replied in #{post.title}",
      body: Common.excerpt(reply.body, @excerpt),
      url: reply_url(community, post, reply.id)
    })
  end

  @spec answer(map()) :: Notice.t()
  def answer(%{actor: actor, community: community, post: post, reply_id: reply_id}) do
    notice(:answer, "replies", %{
      actor: actor,
      community: community,
      subject: {"reply", reply_id},
      data: %{post_id: post.id, post_title: post.title, reply_id: reply_id},
      title: "#{name(actor)} marked your reply as the answer",
      body: post.title,
      url: reply_url(community, post, reply_id)
    })
  end

  @spec mention(map()) :: Notice.t()
  def mention(
        %{actor: actor, community: community, subject: {type, id}, body: body, url: url} = mention
      ) do
    notice(:mention, "mentions", %{
      actor: actor,
      community: community,
      subject: {type, id},
      data:
        Map.merge(%{excerpt: Common.excerpt(body, @excerpt), url: url}, mention[:data] || %{}),
      title: "#{name(actor)} mentioned you in #{community.name}",
      body: Common.excerpt(body, @excerpt),
      url: url
    })
  end

  @spec direct_message(map()) :: Notice.t()
  def direct_message(%{actor: actor, message: message}) do
    %Notice{
      in_app: %InAppMessage{
        kind: :dm,
        actor_id: actor.id,
        subject_type: "message",
        subject_id: message.id,
        data: %{
          conversation_id: message.conversation_id,
          excerpt: Common.excerpt(message.body, @excerpt)
        }
      },
      title: name(actor),
      body: Common.excerpt(message.body, @excerpt),
      url: "/dm/#{actor.username}"
    }
  end

  @spec event_scheduled(map()) :: Notice.t()
  def event_scheduled(%{actor: actor, community: community, event: event}) do
    notice(:event_scheduled, nil, %{
      actor: actor,
      community: community,
      subject: {"event", event.id},
      data: %{event_id: event.id, event_title: event.title, starts_at: event.starts_at},
      title: "#{name(actor)} scheduled #{event.title}",
      body: community.name,
      url: event_url(community, event)
    })
  end

  @spec live_started(map()) :: Notice.t()
  def live_started(
        %{actor: actor, community: community, room: room, session_id: session_id} = live
      ) do
    notice(:live_started, "live", %{
      actor: actor,
      community: community,
      subject: {"voice_session", session_id},
      data: %{room_slug: room.slug, room_name: room.name, topic: live[:topic]},
      title: "#{name(actor)} is live in #{room.name}",
      body: live[:topic] || community.name,
      url: "/c/#{community.slug}/voice/#{room.slug}"
    })
  end

  @spec event_reminder(map()) :: Notice.t()
  def event_reminder(%{community: community, event: event, minutes: minutes}) do
    url = event_url(community, event)

    notice(:event_reminder, nil, %{
      actor: nil,
      community: community,
      subject: {"event", event.id},
      data: %{event_id: event.id, event_title: event.title, minutes: minutes},
      title: "#{event.title} starts in #{minutes} minutes",
      body: community.name,
      url: url
    })
  end

  @spec transcript_ready(map()) :: Notice.t()
  def transcript_ready(%{community: community, event: event, session_id: session_id}) do
    notice(:transcript_ready, nil, %{
      actor: nil,
      community: community,
      subject: {"voice_session", session_id},
      data: %{event_id: event.id, event_title: event.title, session_id: session_id},
      title: "The transcript of #{event.title} is ready",
      body: community.name,
      url: "/c/#{community.slug}/sessions/#{session_id}"
    })
  end

  @spec queued(map()) :: Notice.t()
  def queued(%{community: community, item: item}) do
    held? = item.held

    title =
      case held? do
        true -> "A #{item.subject_type} was held for review in #{community.name}"
        false -> "A #{item.subject_type} was reported in #{community.name}"
      end

    notice(:report, nil, %{
      actor: nil,
      community: community,
      subject: {"moderation_item", item.id},
      data: %{
        item_id: item.id,
        subject_type: item.subject_type,
        subject_id: item.subject_id,
        held: held?
      },
      title: title,
      body: "Open the queue to keep or remove it.",
      url: "/c/#{community.slug}/moderation"
    })
  end

  @spec direct_message_reported(map()) :: Notice.t()
  def direct_message_reported(%{item: item}) do
    %Notice{
      in_app: %InAppMessage{
        kind: :report,
        subject_type: "moderation_item",
        subject_id: item.id,
        data: %{item_id: item.id, subject_type: item.subject_type, subject_id: item.subject_id}
      },
      title: "A direct message was reported",
      body: "Open the reports to keep or remove it.",
      url: "/settings/instance/reports"
    }
  end

  @spec held_for_instance(map()) :: Notice.t()
  def held_for_instance(%{item: item}) do
    %Notice{
      in_app: %InAppMessage{
        kind: :report,
        subject_type: "moderation_item",
        subject_id: item.id,
        data: %{
          item_id: item.id,
          subject_type: item.subject_type,
          subject_id: item.subject_id,
          held: true
        }
      },
      title: "An image was held for review",
      body: "Screening flagged it. Open the reports to keep or remove it.",
      url: "/settings/instance/reports"
    }
  end

  @spec invite(map()) :: Notice.t()
  def invite(%{
        community_id: community_id,
        community_name: community_name,
        inviter_id: inviter_id,
        inviter_name: inviter,
        code: code
      }) do
    %Notice{
      in_app: %InAppMessage{
        kind: :invite,
        actor_id: inviter_id,
        community_id: community_id,
        subject_type: "community",
        subject_id: community_id,
        data: %{code: code, community_name: community_name, inviter_name: inviter}
      },
      title: "#{inviter} invited you to #{community_name}",
      body: "Join on #{Notifications.brand()}",
      url: "/join/#{code}"
    }
  end

  defp notice(kind, setting, fields) do
    {subject_type, subject_id} = fields.subject

    %Notice{
      in_app: %InAppMessage{
        kind: kind,
        actor_id: get_in(fields.actor.id),
        community_id: fields.community.id,
        subject_type: subject_type,
        subject_id: subject_id,
        data:
          Map.merge(fields.data, %{
            community_slug: fields.community.slug,
            community_name: fields.community.name
          })
      },
      title: fields.title,
      body: fields.body,
      url: fields.url,
      setting: setting
    }
  end

  defp event_url(community, event),
    do: "/c/#{community.slug}/e/#{Common.id_slug(event.id, event.title)}"

  @spec post_url(map(), map()) :: String.t()
  def post_url(community, post),
    do: "/c/#{community.slug}/p/#{Common.id_slug(post.id, post.title)}"

  @spec reply_url(map(), map(), T.id()) :: String.t()
  def reply_url(community, post, reply_id), do: post_url(community, post) <> "/r/#{reply_id}"

  defp name(user), do: user.display_name || user.username
end
