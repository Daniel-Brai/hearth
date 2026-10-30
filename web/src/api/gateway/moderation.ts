import type { ContentRef, HearthGateway, Result } from '@/data/gateway';
import { fail, ok } from '@/data/gateway';
import type { AppState } from '@/domain/app-state';
import type { Ban, ModLogAction, ModLogEntry, QueueItem } from '@/domain/types';
import {
  banCreate,
  banIndex,
  banLift,
  moderationBanAuthor,
  moderationCounts,
  moderationInstanceQueue,
  moderationKeep,
  moderationLog,
  moderationQueue,
  moderationRemove,
  moderationRemoveContent,
  moderationRestoreContent,
  moderationUndo,
  reportCreate,
} from '@/generated/api/moderation/moderation';
import type {
  Ban as ApiBan,
  ModerationAction,
  QueueItem as ApiQueueItem,
  QueueItemSubjectType,
} from '@/generated/schemas';
import { ageOf, toPerson } from '../mappers';
import type { GatewayContext } from './context';
import { call, errorCode, failed } from './context';

const KINDS = { post: 'Post', reply: 'Reply', message: 'Message' } as const satisfies Record<
  QueueItemSubjectType,
  QueueItem['kind']
>;

const SUBJECTS = { Post: 'post', Reply: 'reply', Message: 'message' } as const satisfies Record<
  QueueItem['kind'],
  QueueItemSubjectType
>;

const REFUSALS: Record<string, string> = {
  reports_off: "Reports are off here, so this can't be reported.",
  own: "You can't report your own post or message.",
  already_reported: "You've already reported this. A moderator will take a look.",
  reason_required: 'Say why. It goes in the public log.',
  not_removed: "That isn't removed.",
  invalid_transition: 'Someone already decided on that one.',
  stale: 'That changed since you loaded it. Look again.',
};

const refused = (answer: { status: number; data: unknown }): Result<never> => {
  const code = errorCode(answer);
  const sentence = code ? REFUSALS[code] : undefined;

  if (sentence) return fail(sentence);
  if (answer.status === 403) return fail("You don't have permission to do that here.");

  return failed(answer);
};

const DAY_MS = 24 * 60 * 60 * 1000;

const expiresAt = (until: string): string | null => {
  const days = Number.parseInt(until, 10);
  return Number.isFinite(days) ? new Date(Date.now() + days * DAY_MS).toISOString() : null;
};

const untilText = (expires: string | null) =>
  expires
    ? 'Until ' + new Date(expires).toLocaleDateString('en', { month: 'short', day: 'numeric' })
    : 'permanent';

const LOG_TEXT: Record<ModLogAction, string> = {
  removed: 'removed',
  restored: 'restored',
  kept: 'kept',
  banned: 'banned',
  unbanned: 'lifted the ban on',
  queued: 'queued',
  pinned: 'pinned',
  locked: 'locked',
  changed: 'changed',
  server_muted: 'server muted',
  server_mute_lifted: 'lifted the server mute on',
  disconnected: 'disconnected',
  moved_to_listeners: 'moved',
  recording_started: 'started recording',
  recording_stopped: 'stopped recording',
};

const ON_PERSON = new Set<ModLogAction>([
  'banned',
  'unbanned',
  'server_muted',
  'server_mute_lifted',
  'disconnected',
  'moved_to_listeners',
]);

// The server decides who may act so a refusal shows as its sentence
export function createModerationGateway(
  ctx: GatewayContext,
  loadCommunity: (cid: string) => Promise<Result>,
) {
  const communityId = async (cid: string) => {
    if (ctx.needsDetail(cid)) await loadCommunity(cid);
    return ctx.communityIds.get(cid) ?? null;
  };

  const placeOf = (item: ApiQueueItem): string => {
    if (!item.community_id) return 'in a direct message';

    const room = item.room_id ? ctx.roomsById.get(item.room_id) : null;

    if (room) return 'in #' + room.slug;

    return item.subject_type === 'reply' ? 'on a post' : 'in the feed';
  };

  const toQueueItem = (item: ApiQueueItem, state: AppState): QueueItem => {
    if (item.author) state.people[item.author.id] ??= toPerson(item.author);

    const reports = item.reports.map((r) => ({
      reason: r.reason,
      note: r.note,
      age: ageOf(r.inserted_at),
    }));

    const room = item.room_id ? ctx.roomsById.get(item.room_id) : null;

    return {
      id: item.id,
      c: item.community_id ? (ctx.communitySlugs.get(item.community_id) ?? 'dm') : 'dm',
      ...(room ? { r: room.slug } : {}),
      kind: KINDS[item.subject_type],
      who: item.author?.id ?? '',
      where: placeOf(item),
      text: item.subject ? (item.subject.title ?? item.subject.body) : 'This is gone.',
      reason:
        item.source === 'automatic'
          ? (item.reason ?? 'Held by screening.')
          : `Reported ${item.report_count === 1 ? 'once' : `${item.report_count} times`}.`,
      score: item.score ?? 0,
      status: item.status,
      age: ageOf(item.inserted_at),
      reported: item.source !== 'automatic',
      source: item.source,
      reports,
      subject: {
        type: item.subject_type,
        id: item.subject_id,
        postId: item.subject?.post_id ?? null,
      },
    };
  };

  const putQueue = (items: readonly ApiQueueItem[], keep: (x: QueueItem) => boolean) =>
    ctx.store.set((state) => {
      state.queue = [...state.queue.filter(keep), ...items.map((x) => toQueueItem(x, state))];
    });

  const putItem = (item: ApiQueueItem) =>
    ctx.store.set((state) => {
      const next = toQueueItem(item, state);
      const at = state.queue.findIndex((x) => x.id === item.id);

      if (at >= 0) state.queue[at] = next;
      else state.queue.unshift(next);
    });

  const toLog = (entry: ModerationAction, cid: string, state: AppState): ModLogEntry => {
    if (entry.actor) state.people[entry.actor.id] ??= toPerson(entry.actor);

    const target = entry.target ? ' @' + entry.target.username : '';
    const thing = entry.subject_type === 'user' ? '' : ' a ' + entry.subject_type;
    const level = typeof entry.metadata['level'] === 'string' ? entry.metadata['level'] : null;
    let text: string;

    if (entry.action === 'changed' && level) {
      text = `set moderation to ${level === 'reports' ? 'reports only' : level}`;
    } else if (ON_PERSON.has(entry.action)) {
      text = `${LOG_TEXT[entry.action]}${target}${entry.action === 'moved_to_listeners' ? ' to listeners' : ''}`;
    } else {
      text = `${LOG_TEXT[entry.action]}${thing}${target ? ` by${target}` : ''}`;
    }

    return {
      id: entry.id,
      who: entry.actor?.id ?? '',
      action: entry.action,
      text,
      reason: entry.reason,
      c: cid,
      age: ageOf(entry.inserted_at),
    };
  };

  const toBan = (ban: ApiBan, cid: string, state: AppState): Ban => {
    if (ban.banned_by) state.people[ban.banned_by.id] ??= toPerson(ban.banned_by);

    return {
      id: ban.id,
      name: ban.user?.username ?? 'someone',
      c: cid,
      reason: ban.reason ?? 'No reason given',
      by: ban.banned_by?.id ?? '',
      age: ageOf(ban.inserted_at),
      until: untilText(ban.expires_at),
    };
  };

  const loadCounts = async () => {
    const answer = await call(() => moderationCounts());
    if (answer.status !== 200) return;

    ctx.store.set((state) => {
      state.queueCounts = {};
      for (const [id, n] of Object.entries(answer.data.counts)) {
        const slug = ctx.communitySlugs.get(id);
        if (slug) state.queueCounts[slug] = n;
      }
    });
  };

  const loadLog = async (cid: string): Promise<Result> => {
    const id = await communityId(cid);

    if (!id) return fail("This community isn't here.");

    const answer = await call(() => moderationLog(id));

    if (answer.status !== 200) return failed(answer);

    ctx.store.set((state) => {
      state.modlog = [
        ...state.modlog.filter((l) => l.c !== cid),
        ...answer.data.data.map((l) => toLog(l, cid, state)),
      ];
    });

    return ok(undefined);
  };

  const loadBans = async (cid: string, id: string) => {
    const answer = await call(() => banIndex(id));
    if (answer.status !== 200) return;

    ctx.store.set((state) => {
      state.bans = [
        ...state.bans.filter((b) => b.c !== cid),
        ...answer.data.filter((b) => !b.lifted_at).map((b) => toBan(b, cid, state)),
      ];
    });
  };

  const loadModeration = async (cid: string): Promise<Result> => {
    const log = await loadLog(cid);

    if (!log.ok) return log;

    const id = ctx.communityIds.get(cid)!;
    const permissions = ctx.store.get().communities[cid]?.permissions ?? [];

    const queue = permissions.includes('content.remove')
      ? call(() => moderationQueue(id, { status: 'pending' })).then((answer) => {
          if (answer.status === 200) putQueue(answer.data.data, (x) => x.c !== cid);
        })
      : null;

    const bans = permissions.includes('member.ban') ? loadBans(cid, id) : null;

    await Promise.all([queue, bans, loadCounts()]);

    return ok(undefined);
  };

  const reportedMessages = async (): Promise<Result> => {
    const answer = await call(() => moderationInstanceQueue({ status: 'pending' }));

    if (answer.status !== 200) return refused(answer);

    putQueue(answer.data.data, (x) => x.c !== 'dm');

    return ok(undefined);
  };

  const decide = async (
    id: string,
    send: () => Promise<{ status: number; data: unknown }>,
  ): Promise<Result> => {
    const answer = await call(send);

    if (answer.status !== 200 && answer.status !== 201) return refused(answer);

    if (answer.status === 200) putItem(answer.data as ApiQueueItem);
    else
      ctx.store.set((state) => {
        const item = state.queue.find((x) => x.id === id);
        if (item) item.status = 'removed';
      });

    void loadCounts();

    return ok(undefined);
  };

  const markContent = (ref: ContentRef, removed: boolean) =>
    ctx.store.set((state) => {
      for (const post of state.posts) {
        if (ref.kind === 'Post' && post.id === ref.id) {
          post.removed = removed;
          post.moderated = removed;
        }

        const reply = ref.kind === 'Reply' ? post.replies.find((r) => r.id === ref.id) : null;

        if (reply) {
          reply.removed = removed;
          reply.moderated = removed;
        }
      }

      if (ref.kind !== 'Message') return;

      for (const messages of Object.values(state.chats)) {
        const m = messages.find((x) => x.id === ref.id);

        if (!m) continue;
        m.system = removed;
        m.moderated = removed;
        if (removed) m.text = 'Removed by a moderator';
      }
    });

  const moderation: HearthGateway['moderation'] = {
    keep: (id) => decide(id, () => moderationKeep(id, {})),
    remove: (id, reason) => {
      if (!reason.trim()) return Promise.resolve(fail(REFUSALS['reason_required']!));
      return decide(id, () => moderationRemove(id, { reason }));
    },
    undo: (id) => decide(id, () => moderationUndo(id)),
    banFromQueue: (id, reason) => {
      if (!reason.trim()) return Promise.resolve(fail(REFUSALS['reason_required']!));
      return decide(id, () => moderationBanAuthor(id, { reason }));
    },

    report: async (spec) => {
      const answer = await call(() =>
        reportCreate({
          subject_type: SUBJECTS[spec.kind],
          subject_id: spec.id,
          reason: spec.reason,
          note: spec.note?.trim() || null,
        }),
      );

      if (answer.status !== 201) return refused(answer);

      // A post you reported leaves Catch up at once, as the server's next answer would say
      if (spec.kind === 'Post')
        ctx.store.set((state) => {
          const post = state.posts.find((p) => p.id === spec.id);

          if (!post) return;
          post.reported = true;
          post.inReview = true;
        });

      return ok({ queued: answer.data.queued });
    },

    removeContent: async (ref, reason) => {
      if (!reason.trim()) return fail(REFUSALS['reason_required']!);

      const answer = await call(() =>
        moderationRemoveContent({ subject_type: SUBJECTS[ref.kind], subject_id: ref.id, reason }),
      );

      if (answer.status !== 200) return refused(answer);

      markContent(ref, true);

      return ok(undefined);
    },

    restoreContent: async (ref) => {
      const answer = await call(() =>
        moderationRestoreContent({ subject_type: SUBJECTS[ref.kind], subject_id: ref.id }),
      );

      if (answer.status !== 200) return refused(answer);

      markContent(ref, false);
      // The text was dropped from the store while it was removed so it is fetched again
      if (ref.kind === 'Message' && ref.key) void reloadChat(ref.key);

      return ok(undefined);
    },

    ban: async (spec) => {
      const id = await communityId(spec.c);

      if (!id) return fail("This community isn't here.");
      if (!spec.reason.trim()) return fail(REFUSALS['reason_required']!);

      const answer = await call(() =>
        banCreate(id, {
          username: spec.username,
          reason: spec.reason.trim(),
          expires_at: expiresAt(spec.until),
        }),
      );

      if (answer.status !== 201) return refused(answer);

      ctx.store.set((state) => state.bans.unshift(toBan(answer.data, spec.c, state)));
      void loadLog(spec.c);

      return ok(undefined);
    },

    unban: async (id) => {
      const ban = ctx.store.get().bans.find((b) => b.id === id);
      const answer = await call(() => banLift(id, {}));

      if (answer.status !== 200) return refused(answer);

      ctx.store.set((state) => {
        state.bans = state.bans.filter((b) => b.id !== id);
      });

      if (ban) void loadLog(ban.c);

      return ok(undefined);
    },
  };

  let reloadChat: (key: string) => Promise<unknown> = () => Promise.resolve();

  return {
    load: { moderation: loadModeration, moderationLog: loadLog, reportedMessages },
    moderation,
    loadCounts,
    onRestoredMessage: (reload: (key: string) => Promise<unknown>) => (reloadChat = reload),
  };
}
