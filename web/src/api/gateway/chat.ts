import type { HearthGateway, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { AppState } from '@/domain/app-state';
import type { Attachment, LinkPreview, Message } from '@/domain/types';
import {
  conversationCreate,
  conversationIndex,
  messageConversationCreate,
  messageConversationIndex,
  messageDelete,
  messagePreview,
  messageReact,
  messageRoomCreate,
  messageRoomIndex,
  messageUpdate,
  unreadShow,
} from '@/generated/api/chat/chat';
import { postPromote } from '@/generated/api/forum/forum';
import { linkPreviewShow } from '@/generated/api/media/media';
import { sendFiles } from '../attachments';
import { toAttachments, toLinkPreview, toMessage, toPerson, timeOf } from '../mappers';
import { getRealtime } from '../realtime';
import type { Topic } from '../realtime';
import { setCount, setMine } from './boosts';
import type { GatewayContext } from './context';
import { call, errorCode, failed } from './context';

type Place = { kind: 'room' | 'conversation'; id: string };
type Paging = { parent_id?: string };
type Body = { body: string; reply_to_id: string | null; attachment_ids: string[] };

const topicOf = (place: Place): Topic => `${place.kind}:${place.id}`;

// Someone shows as typing until this long after their last word, and ours goes out at most this often
const TYPING_SHOWN_MS = 5000;
const TYPING_EVERY_MS = 3000;

function listMessages(place: Place, params: Paging) {
  if (place.kind === 'room') return messageRoomIndex(place.id, params);

  return messageConversationIndex(place.id, params);
}

function createMessage(place: Place, body: Body) {
  if (place.kind === 'room') return messageRoomCreate(place.id, body);

  return messageConversationCreate(place.id, body);
}

const setContent = (
  state: AppState,
  key: string,
  id: string,
  content: { text: string; files: readonly Attachment[] },
) => {
  const message = state.chats[key]?.find((m) => m.id === id);

  if (!message) return;

  message.text = content.text;
  message.files = [...content.files];
  message.edited = true;
};

const setBoost = (state: AppState, key: string, id: string, emoji: string, on: boolean) => {
  const message = state.chats[key]?.find((m) => m.id === id);
  if (message) setMine(message, emoji, on);
};

export function createChatGateway(
  ctx: GatewayContext,
  loadCommunity: (cid: string) => Promise<Result>,
) {
  const placeOf = async (key: string): Promise<Result<Place>> => {
    if (key.startsWith('dm/')) {
      const who = key.slice(3);
      const known = ctx.conversationIds.get(who);

      if (known) return ok({ kind: 'conversation', id: known });

      const answer = await call(() => conversationCreate({ user_ids: [who] }));

      if (answer.status !== 201) return failed(answer);

      ctx.conversationIds.set(who, answer.data.id);

      return ok({ kind: 'conversation', id: answer.data.id });
    }

    if (!ctx.roomIds.has(key)) {
      const loaded = await loadCommunity(key.slice(0, key.indexOf('/')));
      if (!loaded.ok) return loaded;
    }

    const id = ctx.roomIds.get(key);

    return id ? ok({ kind: 'room', id }) : fail('That room is not in this community.');
  };

  // Every message with the same link shares one request
  const linkPreviews = new Map<string, Promise<LinkPreview | null>>();

  const typingTimers = new Map<string, ReturnType<typeof setTimeout>>();
  const typingSent = new Map<string, number>();

  const setTyping = (key: string, who: string, on: boolean) => {
    const timer = key + ' ' + who;

    clearTimeout(typingTimers.get(timer));
    typingTimers.delete(timer);
    if (on)
      typingTimers.set(
        timer,
        setTimeout(() => setTyping(key, who, false), TYPING_SHOWN_MS),
      );

    const shown = ctx.store.get().typing[key]?.includes(who) ?? false;
    if (on === shown) return;

    ctx.store.set((state) => {
      const others = (state.typing[key] ?? []).filter((id) => id !== who);
      state.typing[key] = on ? [...others, who] : others;
    });
  };

  // A chat nobody has opened yet has no topic to type on
  const knownTopic = (key: string): Topic | null => {
    const dm = key.startsWith('dm/');
    const id = dm ? ctx.conversationIds.get(key.slice(3)) : ctx.roomIds.get(key);

    return id ? topicOf({ kind: dm ? 'conversation' : 'room', id }) : null;
  };

  const fetchMessages = (place: Place, parent: string | null) =>
    call(() => listMessages(place, parent ? { parent_id: parent } : {}));

  const fetchInto = async (key: string, parent: string | null): Promise<Result<Place>> => {
    const place = await placeOf(key);

    if (!place.ok) return place;

    const answer = await fetchMessages(place.value, parent);

    if (answer.status !== 200) return failed(answer);

    ctx.rememberMessages(key, answer.data.data);

    return place;
  };

  const refresh = async (key: string, id: string, removed: boolean) => {
    const parent = ctx.store.get().chats[key]?.find((m) => m.id === id)?.parent ?? null;
    const place = await placeOf(key);

    if (!place.ok) return;

    const answer = await fetchMessages(place.value, parent);

    if (answer.status !== 200) return;

    ctx.rememberMessages(key, answer.data.data);

    if (removed && !answer.data.data.some((m) => m.id === id))
      ctx.store.set((state) => {
        state.chats[key] = (state.chats[key] ?? []).filter((m) => m.id !== id);
      });
  };

  const load = {
    chat: async (key: string) => {
      await ctx.sessionLoaded;

      const place = await fetchInto(key, null);

      if (!place.ok) return place;

      ctx.watch(topicOf(place.value), (realtime, t) => {
        const stops = [
          realtime.onPush(t, 'MessageCreated', (e) => {
            setTyping(key, e.author_id, false);
            void fetchInto(key, null);
          }),
          realtime.onPush(t, 'typing', (e) => {
            if (e.user_id !== ctx.store.get().me) setTyping(key, e.user_id, e.typing);
          }),
          realtime.onPush(t, 'MessageEdited', (e) => void refresh(key, e.message_id, false)),
          // The reactor's own screen changed when they tapped, so only others take the count
          realtime.onPush(t, 'MessageReacted', (e) => {
            if (e.user_id === ctx.store.get().me) return;

            ctx.store.set((state) => {
              const message = state.chats[key]?.find((m) => m.id === e.message_id);
              if (message) setCount(message, e.emoji, e.count);
            });
          }),
          realtime.onPush(t, 'MessageRemoved', (e) => void refresh(key, e.message_id, true)),
          realtime.onPush(t, 'ContentRemoved', (e) => void refresh(key, e.subject_id, false)),
          realtime.onPush(t, 'ContentRestored', (e) => void refresh(key, e.subject_id, false)),
          realtime.onPush(t, 'room_hidden', () => {
            const [cid, rid] = key.split('/');
            if (cid && rid) ctx.dropRoom(cid, rid);
          }),
        ];

        return () => stops.forEach((stop) => stop());
      });

      return ok(undefined);
    },
  } satisfies Partial<HearthGateway['load']>;

  const setDirectUnread = (who: string, unread: number) =>
    ctx.store.set((state) => {
      const direct = state.directs.find((d) => d.who === who);
      if (direct) direct.unread = unread;
    });

  const setRoomUnread = (roomId: string, communityId: string, unread: (was: number) => number) => {
    const rid = ctx.roomsById.get(roomId)?.slug;
    const cid = ctx.communitySlugs.get(communityId);

    if (!rid || !cid) return;

    ctx.store.set((state) => {
      const room = state.communities[cid]?.rooms.find((r) => r.id === rid);
      if (room) room.unread = unread(room.unread);
    });
  };

  // Direct conversations and every unread count, after sign in and when a DM arrives
  const loadInbox = async (): Promise<Result> => {
    const [listed, unread] = await Promise.all([
      call(() => conversationIndex()),
      call(() => unreadShow()),
    ]);

    if (listed.status !== 200) return failed(listed);
    if (unread.status !== 200) return failed(unread);

    const me = ctx.store.get().me;
    const counts = new Map(unread.data.conversations.map((c) => [c.id, c.count]));

    const directs = listed.data.flatMap((conversation) => {
      const other = conversation.members.find((m) => m.id !== me);

      if (conversation.kind !== 'direct' || !other) return [];

      ctx.conversationIds.set(other.id, conversation.id);

      return [{ person: other, unread: counts.get(conversation.id) ?? 0 }];
    });

    ctx.store.set((state) => {
      for (const { person } of directs) state.people[person.id] ??= toPerson(person);
      state.directs = directs.map(({ person, unread: n }) => ({ who: person.id, unread: n }));
    });

    for (const room of unread.data.rooms)
      setRoomUnread(room.id, room.community_id, () => room.count);

    // A new message in a room someone isn't reading adds to its count, and reading it clears it
    for (const communityId of ctx.communitySlugs.keys())
      ctx.watch(
        `community:${communityId}`,
        (realtime, topic) =>
          realtime.onPush(topic, 'RoomActivity', (e) =>
            setRoomUnread(e.room_id, e.community_id, (was) => was + 1),
          ),
        'unread',
      );

    return ok(undefined);
  };

  const chat: HearthGateway['chat'] = {
    open: (key) => {
      if (key.startsWith('dm/')) setDirectUnread(key.slice(3), 0);
    },

    openDm: (who) =>
      ctx.store.set((state) => {
        if (!state.directs.some((d) => d.who === who)) state.directs.unshift({ who, unread: 0 });
      }),

    typing: (key, on) => {
      const topic = knownTopic(key);
      const last = typingSent.get(key);

      if (!topic || (on ? last !== undefined && Date.now() - last < TYPING_EVERY_MS : !last))
        return;

      if (on) typingSent.set(key, Date.now());
      else typingSent.delete(key);

      getRealtime().send(topic, 'typing', { typing: on });
    },

    send: (key, text, opts) => {
      const me = ctx.store.get().me;

      if (!me) return fail('Sign in to send messages.');

      // The message itself clears the others' indicator, so the next word starts a new one
      typingSent.delete(key);

      const files = opts?.files ?? [];

      const draft: Message = {
        id: 'pending-' + ctx.store.nextId('m'),
        who: me,
        text,
        time: timeOf(new Date().toISOString()),
        boosts: [],
        parent: opts?.parent ?? null,
        ...(files.length ? { files } : {}),
      };

      ctx.store.set((state) => (state.chats[key] ??= []).push(draft));

      void placeOf(key).then(async (place) => {
        const sent = place.ok ? await sendFiles(files, text) : null;
        const answer =
          place.ok && sent?.ok
            ? await call(() =>
                createMessage(place.value, {
                  body: sent.value.body,
                  reply_to_id: opts?.parent ?? null,
                  attachment_ids: sent.value.ids,
                }),
              )
            : null;

        ctx.store.set((state) => {
          const messages = (state.chats[key] ?? []).filter((m) => m.id !== draft.id);

          if (answer?.status === 201 && !messages.some((m) => m.id === answer.data.id))
            messages.push({
              ...toMessage(answer.data),
              files: toAttachments(answer.data.attachments, files),
            });

          state.chats[key] = messages;
        });
      });

      return ok({});
    },

    commands: () => [],

    edit: (key, id, patch) => {
      if (!patch.text.trim() && patch.files.length === 0)
        return fail('A message needs some text or a file. Delete it instead.');

      const message = ctx.store.get().chats[key]?.find((m) => m.id === id);
      const before = message && { text: message.text, files: message.files ?? [] };

      ctx.store.set((state) => setContent(state, key, id, patch));

      void sendFiles(patch.files, patch.text).then(async (sent) => {
        const answer = sent.ok
          ? await call(() =>
              messageUpdate(id, { body: sent.value.body, attachment_ids: sent.value.ids }),
            )
          : null;

        if (answer?.status === 200) {
          const files = toAttachments(answer.data.attachments, patch.files);
          ctx.store.set((state) =>
            setContent(state, key, id, { text: answer.data.body ?? '', files }),
          );
        } else if (before) {
          ctx.store.set((state) => setContent(state, key, id, before));
        }
      });

      return ok(undefined);
    },

    remove: (key, id) => {
      ctx.store.set((state) => {
        state.chats[key] = (state.chats[key] ?? []).filter((m) => m.id !== id);
      });

      void call(() => messageDelete(id)).then((answer) => {
        if (answer.status !== 204) void fetchInto(key, null);
      });
    },

    toggleBoost: (key, id, emoji) => {
      if (id.startsWith('pending-')) return;

      const message = ctx.store.get().chats[key]?.find((m) => m.id === id);
      const was = message?.boosts.some((b) => b.e === emoji && b.mine) ?? false;

      ctx.store.set((state) => setBoost(state, key, id, emoji, !was));

      void call(() => messageReact(id, { emoji })).then((answer) => {
        const on = answer.status === 200 ? answer.data.on : was;
        ctx.store.set((state) => setBoost(state, key, id, emoji, on));
      });
    },
    hidePreview: (key, id) => {
      const setHidden = (hidden: boolean) =>
        ctx.store.set((state) => {
          const message = state.chats[key]?.find((m) => m.id === id);
          if (message) message.previewHidden = hidden;
        });

      setHidden(true);

      void call(() => messagePreview(id, { hidden: true })).then((answer) => {
        if (answer.status !== 204) setHidden(false);
      });
    },

    linkPreview: (url) => {
      const known = linkPreviews.get(url);
      if (known) return known;

      const preview = call(() => linkPreviewShow({ url })).then((answer) =>
        answer.status === 200 ? toLinkPreview(answer.data) : null,
      );

      linkPreviews.set(url, preview);

      return preview;
    },

    loadReplies: async (key, parent) => {
      const place = await fetchInto(key, parent);

      return place.ok ? ok(undefined) : place;
    },

    promote: async (key, ids, spec) => {
      const roomId = ctx.roomIds.get(key);
      const kindId = ctx.kindIds.get(`${key.slice(0, key.indexOf('/'))}/${spec.kind}`);

      if (!roomId || !kindId) return fail('That room is not loaded.');

      const answer = await call(() =>
        postPromote(roomId, { message_ids: ids, kind_id: kindId, title: spec.title.trim() }),
      );

      if (errorCode(answer) === 'private_room')
        return fail("Messages in a private room can't become a post.");

      if (answer.status !== 201) return failed(answer);

      const [post] = ctx.rememberPosts([answer.data]);

      return ok({ post: post! });
    },
  };

  return { load, chat, loadInbox };
}
