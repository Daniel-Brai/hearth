import type { Result } from '@/data/gateway';
import { onServer } from '@/data/env';
import { fail, ok } from '@/data/gateway';
import type { Store } from '@/data/store';
import { lexMarkdown } from '@/features/markdown/markdown';
import { userIndex } from '@/generated/api/people/people';
import type { RoomSettings } from '@/domain/types';
import type { ChatMessage, Community, CommunityDetail, Post, Reply } from '@/generated/schemas';
import { toCommunity, toMessage, toPerson, toPost, toReply } from '../mappers';
import { getRealtime } from '../realtime';
import type { Realtime, Topic } from '../realtime';

type Answer = { status: number; data: unknown };

export const UNREACHABLE = "Can't reach the Hearth server.";

export const NOT_READY = "This isn't available on this server yet.";

const SERVER_TROUBLE = 'The Hearth server ran into a problem. Try again in a moment.';

export const OUTAGES: ReadonlySet<string> = new Set([UNREACHABLE, SERVER_TROUBLE]);

export async function call<A extends Answer>(
  request: () => Promise<A>,
): Promise<A | { status: 0; data: null }> {
  try {
    return await request();
  } catch (error) {
    if (error instanceof TypeError) return { status: 0, data: null };
    throw error;
  }
}

export function errorCode(answer: Answer): string | null {
  const data = answer.data as { code?: unknown } | null;
  return typeof data?.code === 'string' ? data.code : null;
}

// Any 2xx when the caller needs nothing back
export const answered = (answer: Answer): Result =>
  answer.status >= 200 && answer.status < 300 ? ok(undefined) : failed(answer);

export function failed(answer: Answer): Result<never> {
  if (answer.status === 0) return fail(UNREACHABLE);
  if (answer.status >= 500) return fail(SERVER_TROUBLE);

  const data = answer.data as { message?: string; errors?: Record<string, string[]> } | null;
  const field = data?.errors ? Object.entries(data.errors)[0] : undefined;

  if (field) return fail(`${field[0].replaceAll('_', ' ')} ${field[1][0] ?? 'is not valid'}`);

  return fail(data?.message ?? 'Something went wrong. Try again.');
}

export const roomDefaults = (): RoomSettings => ({
  topic: null,
  previews: true,
  sounds: { enabled: true, mode: 'everyone', roles: [], people: [] },
});

// The API wants ids so they are kept here as each response arrives
export class GatewayContext {
  readonly store: Store;
  readonly communityIds = new Map<string, string>();
  readonly communitySlugs = new Map<string, string>();
  readonly roomIds = new Map<string, string>();
  readonly roomsById = new Map<string, { slug: string; type: 'text' | 'voice' }>();
  readonly kindIds = new Map<string, string>();
  readonly conversationIds = new Map<string, string>();
  private readonly kindNames = new Map<string, string>();
  private readonly kindsFor = new Set<string>();
  private readonly watching = new Map<string, () => void>();

  // Waits for the session so a first load doesn't read as signed out
  sessionLoaded: Promise<unknown> = Promise.resolve();

  constructor(store: Store) {
    this.store = store;
  }

  rememberCommunity(community: Community, detail: CommunityDetail | null): string {
    const slug = community.slug;

    this.communityIds.set(slug, community.id);
    this.communitySlugs.set(community.id, slug);

    for (const room of community.rooms) {
      this.roomIds.set(`${slug}/${room.slug}`, room.id);
      this.roomsById.set(room.id, { slug: room.slug, type: room.type });
    }

    if (detail) this.kindsFor.add(community.id);
    if (detail) this.detailFor.set(community.id, this.store.get().me);

    for (const kind of detail?.kinds ?? []) {
      this.kindNames.set(kind.id, kind.label);
      this.kindIds.set(`${slug}/${kind.label}`, kind.id);
    }

    this.store.set((state) => {
      const before = state.communities[slug];
      const next = toCommunity(community, detail);

      // A list answer has no kinds or membership so keep those from an earlier detail
      if (!detail && before) {
        next.kinds = before.kinds;
        next.permissions = before.permissions;
      }

      // A community answer knows nothing of live sessions so a room the voice
      // gateway saw go live keeps that until its session ends
      const wasById = new Map(before?.voice.map((v) => [v.id, v]));

      for (const room of next.voice) {
        const was = wasById.get(room.id);
        if (was?.live) Object.assign(room, { ...was, name: room.name });
      }

      state.communities[slug] = next;
      if (community.owner) state.people[community.owner.id] ??= toPerson(community.owner);

      // The server keeps only the topic and the rest of a room's settings stay in this browser
      for (const room of community.rooms) {
        if (room.type !== 'text') continue;

        const key = `${slug}/${room.slug}`;

        const settings = {
          ...(state.roomSettings[key] ?? roomDefaults()),
          topic: room.topic,
        };

        // A room with no level of its own follows the community
        if (room.moderation) settings.moderation = room.moderation;
        else delete settings.moderation;

        state.roomSettings[key] = settings;
      }
    });

    return slug;
  }

  private readonly askedFor = new Set<string>();

  rememberMentions(bodies: readonly (string | null)[]) {
    const known = new Set(
      Object.values(this.store.get().people).map((p) => p.username.toLowerCase()),
    );

    const unknown = [...new Set(bodies.flatMap((body) => (body ? lexMarkdown(body).mentions : [])))]
      .map((handle) => handle.toLowerCase())
      .filter((handle) => !known.has(handle) && !this.askedFor.has(handle))
      .slice(0, 50);

    if (!unknown.length) return;
    for (const handle of unknown) this.askedFor.add(handle);

    void call(() => userIndex({ usernames: unknown.join(',') })).then((answer) => {
      if (answer.status !== 200) return;

      this.store.set((state) => {
        for (const user of answer.data) state.people[user.id] ??= toPerson(user);
      });
    });
  }

  knowsKindsOf(communityId: string): boolean {
    return this.kindsFor.has(communityId);
  }

  // The server renders signed out so its answer has no permissions for whoever signs in
  private readonly detailFor = new Map<string, string | null>();

  hasDetailFor(communityId: string): boolean {
    return (
      this.detailFor.has(communityId) && this.detailFor.get(communityId) === this.store.get().me
    );
  }

  // A post made from a room that is gone no longer says where it started
  private fromChat({ from_chat }: Post) {
    const room = from_chat?.room_id ? this.roomsById.get(from_chat.room_id) : undefined;

    return from_chat && room ? { room: room.slug, count: from_chat.message_count } : null;
  }

  rememberPosts(posts: readonly Post[]) {
    this.rememberMentions(posts.map((p) => p.body));

    const mapped = posts.map((p) => ({
      ...toPost(
        p,
        this.communitySlugs.get(p.community_id) ?? p.community_id,
        this.kindNames.get(p.kind_id) ?? '',
      ),
      fromChat: this.fromChat(p),
    }));

    this.store.set((state) => {
      for (const p of posts) if (p.author) state.people[p.author.id] ??= toPerson(p.author);

      for (const post of mapped) {
        const index = state.posts.findIndex((p) => p.id === post.id);
        const before = state.posts[index];

        if (!before) state.posts.unshift(post);
        else
          state.posts[index] = {
            ...post,
            // An answer from a list that didn't teach the kinds keeps the kind already known
            kind: post.kind || before.kind,
            replies: before.replies,
            // A read can reach the server a few seconds after the screen shows it
            seen: before.seen || post.seen,
          };
      }
    });

    return mapped;
  }

  rememberReplies(postId: string, replies: readonly Reply[]) {
    this.rememberMentions(replies.map((r) => r.body));

    this.store.set((state) => {
      for (const r of replies) if (r.author) state.people[r.author.id] ??= toPerson(r.author);

      const post = state.posts.find((p) => p.id === postId);

      if (!post) return;

      for (const reply of replies.map(toReply)) {
        const index = post.replies.findIndex((r) => r.id === reply.id);
        if (index === -1) post.replies.push(reply);
        else post.replies[index] = reply;
      }
    });
  }

  rememberMessages(key: string, messages: readonly ChatMessage[]) {
    this.rememberMentions(messages.map((m) => m.body));

    this.store.set((state) => {
      for (const m of messages) if (m.author) state.people[m.author.id] ??= toPerson(m.author);

      // Messages already here take the server's text so edits and deletes show
      const fresh = new Map(messages.map((m) => [m.id, toMessage(m)]));

      const kept = (state.chats[key] ?? []).map((m) => {
        const now = fresh.get(m.id);
        return now
          ? {
              ...m,
              text: now.text,
              edited: now.edited ?? false,
              system: now.system ?? false,
              moderated: now.moderated ?? false,
            }
          : m;
      });

      const known = new Set(kept.map((m) => m.id));

      const added = [...messages]
        .reverse()
        .map(toMessage)
        .filter((m) => !known.has(m.id));

      state.chats[key] = [...kept, ...added];
    });
  }

  watch(topic: Topic, listen: (realtime: Realtime, topic: Topic) => () => void, as = 'main') {
    const key = `${topic}#${as}`;
    // The server render answers once and live updates start in the browser
    if (onServer || this.watching.has(key)) return;

    this.watching.set(key, listen(getRealtime(), topic));
  }

  stopWatching() {
    for (const stop of this.watching.values()) stop();
    this.watching.clear();
  }
}
