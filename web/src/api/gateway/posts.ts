import type { HearthGateway, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { AppState } from '@/domain/app-state';
import type { Attachment, Post, Reply, VoiceRoom } from '@/domain/types';
import { communityShow } from '@/generated/api/communities/communities';
import {
  postAnswer,
  postCreate,
  postDelete,
  postHelpful,
  postAllSeen,
  postCommunitySeen,
  postLock,
  postPin,
  postReact,
  postSeen,
  postShow,
  postUpdate,
  postWatch,
  replyCreate,
  replyDelete,
  replyHelpful,
  replyIndex,
  replyUpdate,
} from '@/generated/api/forum/forum';
import { recordingPostIndex, voiceDiscuss } from '@/generated/api/voice/voice';
import { draftDelete, draftIndex, draftUpdate } from '@/generated/api/forum/forum';
import type { Media, Post as ApiPost } from '@/generated/schemas';
import { sendFiles } from '../attachments';
import { sfx } from '@/runtime/sounds';
import { useUi } from '@/runtime/ui-store';
import { paragraphs, toAttachments, toRecording, toReply, toTranscriptSummary } from '../mappers';
import { accessToken } from '../session-token';
import { setCount, setMine } from './boosts';
import type { GatewayContext } from './context';
import { answered, call, errorCode, failed } from './context';

const setPinned = (state: AppState, id: string, pinned: boolean) => {
  const post = state.posts.find((p) => p.id === id);
  if (post) post.pinned = pinned;
};

const setLocked = (state: AppState, id: string, locked: boolean) => {
  const post = state.posts.find((p) => p.id === id);
  if (post) post.locked = locked;
};

const setWatching = (state: AppState, id: string, watching: boolean) => {
  const post = state.posts.find((p) => p.id === id);
  if (post) post.watching = watching;
};

const findReply = (state: AppState, postId: string, replyId: string) =>
  state.posts.find((p) => p.id === postId)?.replies.find((r) => r.id === replyId);

const LIVE_REFUSALS: Record<string, string> = {
  forbidden: 'Only the person who wrote the post can start a live discussion on it.',
  rooms_busy: 'Every voice room here is busy right now. Try again when one is free.',
  no_voice_room: 'This community has no voice room yet.',
  unavailable: "Voice rooms aren't available on this server right now.",
};

export function createPostsGateway(ctx: GatewayContext) {
  // Files the server is still processing keep the preview picked in this browser
  const keepPreviews = (id: string, media: readonly Media[], local: readonly Attachment[]) =>
    ctx.store.set((state) => {
      const post = state.posts.find((p) => p.id === id);
      if (post) post.files = toAttachments(media, local);
    });

  const putReply = (postId: string, reply: Reply) =>
    ctx.store.set((state) => {
      const post = state.posts.find((p) => p.id === postId);

      if (!post) return;

      const index = post.replies.findIndex((r) => r.id === reply.id);

      if (index >= 0) post.replies[index] = reply;
      else post.replies.push(reply);
    });

  const fetchReplies = async (postId: string, parent: string | null): Promise<Result> => {
    const answer = await call(() => replyIndex(postId, parent ? { parent_id: parent } : {}));

    if (answer.status !== 200) return failed(answer);

    ctx.rememberReplies(postId, answer.data.data);

    return ok(undefined);
  };

  const moderated = async (
    postId: string,
    event: { subject_type: 'post' | 'reply' | 'message'; subject_id: string },
  ) => {
    if (event.subject_type === 'reply') {
      const post = ctx.store.get().posts.find((p) => p.id === postId);
      const parent = post?.replies.find((r) => r.id === event.subject_id)?.parent ?? null;

      await fetchReplies(postId, parent);

      return;
    }

    const shown = await call(() => postShow(postId));

    if (shown.status === 200) ctx.rememberPosts([shown.data]);
    else if (shown.status === 404)
      ctx.store.set((state) => {
        state.posts = state.posts.filter((p) => p.id !== postId);
      });
  };

  const flipHelpful = (
    find: (state: AppState) => { helpful: number; helpfulMine: boolean } | undefined,
  ) =>
    ctx.store.set((state) => {
      const item = find(state);

      if (!item) return;

      item.helpfulMine = !item.helpfulMine;
      item.helpful += item.helpfulMine ? 1 : -1;
    });

  const putLive = (communityId: string, roomId: string, change: Partial<VoiceRoom>) => {
    const cid = ctx.communitySlugs.get(communityId);
    const rid = ctx.roomsById.get(roomId)?.slug;

    if (!cid || !rid) return;

    ctx.store.set((state) => {
      const room = state.communities[cid]?.voice.find((v) => v.id === rid);
      if (room) Object.assign(room, change);
    });
  };

  const loadRecordings = async (postId: string, communityId: string) => {
    const cid = ctx.communitySlugs.get(communityId);

    if (!cid || !accessToken()) return;

    const answer = await call(() => recordingPostIndex(postId));

    if (answer.status !== 200) return;

    ctx.store.set((state) => {
      for (const [key, r] of Object.entries(state.recordings))
        if (r.postId === postId) delete state.recordings[key];
      for (const r of answer.data.data) {
        const rid = ctx.roomsById.get(r.room_id)?.slug ?? '';
        const room = state.communities[cid]?.voice.find((v) => v.id === rid)?.name ?? '';
        state.recordings[r.id] = toRecording(r, cid, rid, room, { postId });
      }
    });
  };

  // Returns the posts it changed so a refusal can put them back
  const setSeen = (which: (post: Post) => boolean) =>
    ctx.store.set((state) => {
      const changed = state.posts.filter((p) => !p.seen && which(p));
      for (const post of changed) post.seen = true;
      return changed.map((p) => p.id);
    });

  const setUnseen = (ids: readonly string[]) => {
    const unseen = new Set(ids);

    ctx.store.set((state) => {
      for (const post of state.posts) if (unseen.has(post.id)) post.seen = false;
    });
  };

  const putTranscript = (post: ApiPost) => {
    const cid = ctx.communitySlugs.get(post.community_id);
    const summary = cid ? toTranscriptSummary(post, cid) : null;

    if (!summary) return;

    ctx.store.set((state) => {
      state.transcripts[summary.id] ??= summary;
    });
  };

  // Takes what changed from the server, such as an answer someone marked or a new transcript
  const refreshPost = async (id: string) => {
    const shown = await call(() => postShow(id));

    if (shown.status !== 200) return;

    ctx.rememberPosts([shown.data]);
    putTranscript(shown.data);
  };

  const load = {
    post: async (id: string) => {
      await ctx.sessionLoaded;

      const shown = await call(() => postShow(id));

      if (shown.status !== 200) return failed(shown);

      // A list answer carries no kinds, and one fetched for someone else no permissions
      if (!ctx.hasDetailFor(shown.data.community_id)) {
        const community = await call(() => communityShow(shown.data.community_id));
        if (community.status === 200)
          ctx.rememberCommunity(community.data.community, community.data);
      }

      ctx.rememberPosts([shown.data]);
      putTranscript(shown.data);

      const communityId = shown.data.community_id;
      const live = shown.data.live;

      if (live)
        putLive(communityId, live.room_id, {
          live: true,
          postId: id,
          mode: live.mode,
          host: shown.data.author?.id ?? '',
        });

      void loadRecordings(id, communityId);

      const replies = await fetchReplies(id, null);

      if (!replies.ok) return replies;

      ctx.watch(`post:${id}`, (realtime, topic) => {
        const stops = [
          realtime.onPush(
            topic,
            'ReplyCreated',
            ({ post_id, parent_reply_id }) => void fetchReplies(post_id, parent_reply_id),
          ),
          realtime.onPush(topic, 'ContentRemoved', (e) => void moderated(id, e)),
          realtime.onPush(topic, 'ContentRestored', (e) => void moderated(id, e)),
          // Only the people reading the post hear that its author went live
          realtime.onPush(topic, 'VoiceSessionStarted', (e) => {
            putLive(e.community_id, e.room_id, {
              live: true,
              postId: id,
              mode: e.mode,
              topic: e.topic,
              host: e.host_id ?? '',
              listeners: 1,
            });

            if (!e.host_id || e.host_id === ctx.store.get().me) return;

            const name = ctx.store.get().people[e.host_id]?.name ?? 'The author';

            sfx('live');
            useUi.getState().flash(`${name} is talking this post through live. Join from the top.`);
          }),
          realtime.onPush(topic, 'VoiceSessionEnded', (e) => {
            putLive(e.community_id, e.room_id, {
              live: false,
              postId: null,
              listeners: 0,
              host: '',
            });
            void loadRecordings(id, communityId);
          }),
          realtime.onPush(
            topic,
            'VoiceRecordingChanged',
            () => void loadRecordings(id, communityId),
          ),
          realtime.onPush(topic, 'VoiceRecordingDeleted', (e) =>
            ctx.store.set((state) => {
              delete state.recordings[e.recording_id];
            }),
          ),
          realtime.onPush(topic, 'VoiceRecordingRenamed', (e) =>
            ctx.store.set((state) => {
              const r = state.recordings[e.recording_id];
              if (r) r.title = e.title;
            }),
          ),
          realtime.onPush(topic, 'TranscriptReady', () => void refreshPost(id)),
          realtime.onPush(topic, 'AnswerMarked', () => void refreshPost(id)),
          // The reactor's own screen changed when they tapped, so only others take the count
          realtime.onPush(topic, 'PostReacted', (e) => {
            if (e.user_id === ctx.store.get().me) return;

            ctx.store.set((state) => {
              const found = state.posts.find((p) => p.id === id);
              if (found) setCount(found, e.emoji, e.count);
            });
          }),
        ];

        return () => stops.forEach((stop) => stop());
      });

      return ok(undefined);
    },
  } satisfies Partial<HearthGateway['load']>;

  const posts: HearthGateway['posts'] = {
    markSeen: async (id) => {
      ctx.store.set((state) => {
        const post = state.posts.find((p) => p.id === id);
        if (post) post.seen = true;
      });

      if (!accessToken()) return ok(undefined);

      return answered(await call(() => postSeen(id)));
    },

    markCommunitySeen: async (cid) => {
      const communityId = ctx.communityIds.get(cid);

      if (!communityId) return fail('That community is not loaded.');

      const unseen = setSeen((p) => p.c === cid);
      const answer = await call(() => postCommunitySeen(communityId));

      if (answer.status !== 204) setUnseen(unseen);

      return answered(answer);
    },

    markAllSeen: async () => {
      const unseen = setSeen(() => true);
      const answer = await call(() => postAllSeen());

      if (answer.status !== 204) setUnseen(unseen);

      return answered(answer);
    },

    toggleHelpful: async (id) => {
      const find = (state: AppState) => state.posts.find((p) => p.id === id);
      flipHelpful(find);

      const answer = await call(() => postHelpful(id));

      if (answer.status !== 200) flipHelpful(find);

      return answered(answer);
    },

    toggleReplyHelpful: async (postId, replyId) => {
      const find = (state: AppState) =>
        state.posts.find((p) => p.id === postId)?.replies.find((r) => r.id === replyId);
      flipHelpful(find);

      const answer = await call(() => replyHelpful(replyId));

      if (answer.status !== 200) flipHelpful(find);

      return answered(answer);
    },

    togglePin: async (id) => {
      const post = ctx.store.get().posts.find((p) => p.id === id);

      if (!post) return fail('That post is not loaded.');

      const pinned = !post.pinned;

      ctx.store.set((state) => setPinned(state, id, pinned));

      const answer = await call(() => postPin(id, { pinned }));

      if (answer.status !== 200) ctx.store.set((state) => setPinned(state, id, !pinned));

      return answered(answer);
    },

    toggleLock: async (id) => {
      const post = ctx.store.get().posts.find((p) => p.id === id);

      if (!post) return fail('That post is not loaded.');

      const locked = !post.locked;

      ctx.store.set((state) => setLocked(state, id, locked));

      const answer = await call(() => postLock(id, { locked }));

      if (answer.status !== 200) ctx.store.set((state) => setLocked(state, id, !locked));

      return answered(answer);
    },

    toggleWatch: async (id) => {
      const post = ctx.store.get().posts.find((p) => p.id === id);

      if (!post) return fail('That post is not loaded.');

      const watching = !post.watching;

      ctx.store.set((state) => setWatching(state, id, watching));

      const answer = await call(() => postWatch(id, { watching }));

      if (answer.status !== 200) ctx.store.set((state) => setWatching(state, id, !watching));

      return answered(answer);
    },

    toggleBoost: async (id, emoji) => {
      const post = ctx.store.get().posts.find((p) => p.id === id);

      if (!post) return fail('That post is not loaded.');

      const was = post.boosts.some((b) => b.e === emoji && b.mine);
      const set = (on: boolean) =>
        ctx.store.set((state) => {
          const found = state.posts.find((p) => p.id === id);
          if (found) setMine(found, emoji, on);
        });

      set(!was);

      const answer = await call(() => postReact(id, { emoji }));

      set(answer.status === 200 ? answer.data.on : was);

      return answered(answer);
    },
    loadReplies: (postId, parent) => fetchReplies(postId, parent),

    create: async (spec) => {
      const communityId = ctx.communityIds.get(spec.c);
      const kindId = ctx.kindIds.get(`${spec.c}/${spec.kind}`);

      if (!communityId || !kindId) return fail('That community is not loaded.');

      const sent = await sendFiles(spec.files ?? [], spec.body);

      if (!sent.ok) return sent;

      const { ids, body } = sent.value;

      const answer = await call(() =>
        postCreate(communityId, { kind_id: kindId, title: spec.title, body, attachment_ids: ids }),
      );

      if (answer.status !== 201) return failed(answer);

      const [post] = ctx.rememberPosts([answer.data]);

      keepPreviews(answer.data.id, answer.data.attachments, spec.files ?? []);

      return ok({ post: post! });
    },

    edit: async (id, patch) => {
      const before = ctx.store.get().posts.find((p) => p.id === id);

      if (!before) return fail('That post is gone.');

      const title = patch.title.trim();

      if (!title) return fail('A post needs a title.');

      const kindId = ctx.kindIds.get(`${before.c}/${patch.kind}`);

      if (!kindId) return fail('That kind of post is not loaded.');

      // The change shows at once and goes back if a file doesn't upload or the server refuses it
      ctx.store.set((state) => {
        const post = state.posts.find((p) => p.id === id);

        if (!post) return;

        post.title = title;
        post.body = paragraphs(patch.body);
        post.kind = patch.kind;
        post.files = [...patch.files];
        post.editedAt = new Date().toISOString();
      });

      const restore = () =>
        ctx.store.set((state) => {
          const index = state.posts.findIndex((p) => p.id === id);
          if (index >= 0) state.posts[index] = { ...before, replies: state.posts[index]!.replies };
        });

      const sent = await sendFiles(patch.files, patch.body.trim());

      if (!sent.ok) {
        restore();
        return sent;
      }

      const answer = await call(() =>
        postUpdate(id, {
          title,
          body: sent.value.body,
          kind_id: kindId,
          attachment_ids: sent.value.ids,
        }),
      );

      if (answer.status === 200) {
        ctx.rememberPosts([answer.data]);
        keepPreviews(id, answer.data.attachments, patch.files);
        return ok(undefined);
      }

      restore();

      if (answer.status === 403) return fail('Only the person who wrote this post can edit it.');

      return failed(answer);
    },
    remove: async (id) => {
      const state = ctx.store.get();
      const index = state.posts.findIndex((p) => p.id === id);
      const before = state.posts[index];

      if (!before) return fail('That post is gone.');

      // Anyone else takes a post down through moderation, with a reason for the log
      if (before.author !== state.me)
        return fail('Only the person who wrote this post can delete it.');

      ctx.store.set((draft) => {
        draft.posts = draft.posts.filter((p) => p.id !== id);
      });

      const answer = await call(() => postDelete(id));

      if (answer.status === 204 || answer.status === 404) return ok(undefined);

      ctx.store.set((draft) => {
        if (!draft.posts.some((p) => p.id === id)) draft.posts.splice(index, 0, before);
      });

      if (answer.status === 403) return fail('Only the person who wrote this post can delete it.');

      return failed(answer);
    },

    toggleAnswer: async (postId, replyId) => {
      const before = ctx.store.get().posts.find((p) => p.id === postId);

      if (!before) return fail('That post is gone.');

      const next = before.answer === replyId ? null : replyId;

      const setAnswer = (value: string | null) =>
        ctx.store.set((state) => {
          const post = state.posts.find((p) => p.id === postId);
          if (post) post.answer = value;
        });

      setAnswer(next);

      const answer = await call(() => postAnswer(postId, { reply_id: next }));

      if (answer.status === 200) {
        ctx.rememberPosts([answer.data]);
        return ok(undefined);
      }

      setAnswer(before.answer);

      if (answer.status === 403)
        return fail('Only the person who asked or a moderator can mark the answer.');

      if (answer.status === 404) return fail('This kind of post has no answer to mark.');

      return failed(answer);
    },

    // The reply shows at once and leaves again if a file doesn't upload or the server refuses it
    reply: async (postId, spec) => {
      const me = ctx.store.get().me;

      if (!me) return fail('Sign in to reply.');

      const draft: Reply = {
        id: 'pending-' + ctx.store.nextId('r'),
        parent: spec.parent,
        who: me,
        age: 'now',
        helpful: 0,
        helpfulMine: false,
        body: spec.body.split('\n\n'),
        ...(spec.files?.length ? { files: spec.files } : {}),
      };

      ctx.store.set((state) => state.posts.find((p) => p.id === postId)?.replies.push(draft));

      const files = spec.files ?? [];
      const sent = await sendFiles(files, spec.body);

      const answer = sent.ok
        ? await call(() =>
            replyCreate(postId, {
              body: sent.value.body,
              parent_reply_id: spec.parent,
              attachment_ids: sent.value.ids,
            }),
          )
        : null;

      const created =
        answer?.status === 201
          ? { ...toReply(answer.data), files: toAttachments(answer.data.attachments, files) }
          : null;

      ctx.store.set((state) => {
        const post = state.posts.find((p) => p.id === postId);

        if (!post) return;

        post.replies = post.replies.filter((r) => r.id !== draft.id);

        if (created && !post.replies.some((r) => r.id === created.id)) post.replies.push(created);
      });

      if (created) return ok({ reply: created });
      if (!sent.ok) return sent;

      return failed(answer!);
    },

    editReply: async (postId, replyId, patch) => {
      const text = patch.body.trim();

      if (!text && patch.files.length === 0) return fail('A reply needs some words or a file.');

      const before = findReply(ctx.store.get(), postId, replyId);

      if (!before) return fail('That reply is gone.');

      // The change shows at once and goes back if a file doesn't upload or the server refuses it
      ctx.store.set((state) => {
        const reply = findReply(state, postId, replyId);

        if (!reply) return;
        reply.body = paragraphs(text);
        reply.files = [...patch.files];
        reply.edited = true;
      });

      const sent = await sendFiles(patch.files, text);

      if (!sent.ok) {
        putReply(postId, before);
        return sent;
      }

      const answer = await call(() =>
        replyUpdate(replyId, { body: sent.value.body, attachment_ids: sent.value.ids }),
      );

      if (answer.status === 200) {
        ctx.store.set((state) => {
          const reply = findReply(state, postId, replyId);
          if (reply) reply.files = toAttachments(answer.data.attachments, patch.files);
        });
        return ok(undefined);
      }

      putReply(postId, before);
      if (answer.status === 403) return fail('Only the person who wrote this reply can edit it.');

      return failed(answer);
    },

    removeReply: async (postId, replyId) => {
      const state = ctx.store.get();
      const before = findReply(state, postId, replyId);

      if (!before) return fail('That reply is gone.');

      if (before.who !== state.me)
        return fail('Only the person who wrote this reply can delete it.');

      // One with replies under it stays as a marker so the thread keeps its shape
      ctx.store.set((draft) => {
        const post = draft.posts.find((p) => p.id === postId);
        if (!post) return;

        if (post.replies.some((r) => r.parent === replyId)) {
          const reply = post.replies.find((r) => r.id === replyId);

          if (!reply) return;
          reply.removed = true;
          reply.body = [];
          reply.files = [];
        } else {
          post.replies = post.replies.filter((r) => r.id !== replyId);
        }
      });

      const answer = await call(() => replyDelete(replyId));

      if (answer.status === 204 || answer.status === 404) return ok(undefined);

      putReply(postId, before);
      if (answer.status === 403) return fail('Only the person who wrote this reply can delete it.');

      return failed(answer);
    },
    startLive: async (id) => {
      const answer = await call(() => voiceDiscuss(id));

      if (answer.status !== 200 && answer.status !== 201) {
        const refused = LIVE_REFUSALS[errorCode(answer) ?? ''];
        return refused ? fail(refused) : failed(answer);
      }

      const session = answer.data;
      const rid = ctx.roomsById.get(session.room_id)?.slug;

      if (!rid) return fail('That voice room is not loaded. Reload and try again.');

      putLive(session.community_id, session.room_id, {
        live: true,
        postId: id,
        mode: session.mode,
        topic: session.topic,
        host: session.host_id ?? '',
        listeners: 1,
      });

      return ok({ room: rid });
    },
    saveDraft: async (cid, draft) => {
      const communityId = ctx.communityIds.get(cid);

      ctx.store.set((state) => {
        state.drafts[cid] = { ...draft, updatedAt: new Date().toISOString() };
      });

      if (!communityId) return ok(undefined);

      const kindId = ctx.kindIds.get(`${cid}/${draft.kind}`) ?? null;

      return answered(
        await call(() =>
          draftUpdate(communityId, { title: draft.title, body: draft.body, kind_id: kindId }),
        ),
      );
    },

    discardDraft: async (cid) => {
      const communityId = ctx.communityIds.get(cid);

      ctx.store.set((state) => {
        delete state.drafts[cid];
      });

      if (!communityId) return ok(undefined);

      return answered(await call(() => draftDelete(communityId)));
    },
  };

  // The compose screen reads drafts from the store when it opens so they load after sign in
  const loadDrafts = async () => {
    const answer = await call(() => draftIndex());

    if (answer.status !== 200) return;

    ctx.store.set((state) => {
      for (const draft of answer.data) {
        const cid = ctx.communitySlugs.get(draft.community_id);

        if (cid)
          state.drafts[cid] = {
            title: draft.title ?? '',
            body: draft.body ?? '',
            kind: draft.kind ?? '',
            updatedAt: draft.updated_at,
          };
      }
    });
  };

  return { load, posts, loadDrafts };
}
