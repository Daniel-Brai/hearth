import type { HearthGateway, Result } from '@/data/gateway';
import { ok } from '@/data/gateway';
import { communityMemberIndex } from '@/generated/api/communities/communities';
import { communityShow } from '@/generated/api/communities/communities';
import { peopleIndex } from '@/generated/api/accounts/accounts';
import { userPosts, userReplies, userShow } from '@/generated/api/people/people';
import type { AuthoredReply, Profile } from '@/generated/schemas';
import { personIdByHandle } from '@/domain/selectors';
import type { ProfileActivity } from '@/domain/types';
import { ageOf, paragraphs, toPerson } from '../mappers';
import type { GatewayContext } from './context';
import { call, failed } from './context';

const joinedOf = (iso: string) =>
  new Date(iso).toLocaleDateString([], { month: 'short', year: 'numeric' });

const PAGE = 20;

const NO_ACTIVITY: ProfileActivity = {
  posts: [],
  postsAfter: null,
  replies: [],
  repliesAfter: null,
};

const fromProfile = (profile: Profile) => ({
  ...toPerson(profile),
  helped: profile.counts.people_helped,
  posts: profile.counts.posts,
  answers: profile.counts.answers,
  bio: profile.bio,
  pronouns: profile.pronouns,
  location: profile.location,
  links: profile.links.map((link) => ({ url: link.url, label: link.label })),
  joined: joinedOf(profile.joined_at),
});

export function createPeopleGateway(
  ctx: GatewayContext,
  loadRoles: (cid: string) => Promise<Result>,
) {
  // Someone's posts can sit in communities this browser hasn't seen, whose slugs and kinds come from their detail
  const learnCommunities = (ids: readonly string[]) =>
    Promise.all(
      [...new Set(ids)]
        .filter((id) => !ctx.knowsKindsOf(id))
        .map(async (id) => {
          const answer = await call(() => communityShow(id));
          if (answer.status === 200) ctx.rememberCommunity(answer.data.community, answer.data);
        }),
    );

  const toAuthored = ({ reply, post, answer }: AuthoredReply) => ({
    id: reply.id,
    postId: post.id,
    c: ctx.communitySlugs.get(post.community_id) ?? post.community_id,
    title: post.title,
    excerpt: paragraphs(reply.body)[0] ?? null,
    helpful: reply.helpful_count,
    age: ageOf(reply.inserted_at),
    answer,
  });

  const loadPosts = async (handle: string, id: string, after: string | null) => {
    const answer = await call(() =>
      userPosts(handle, after ? { after, limit: PAGE } : { limit: PAGE }),
    );

    if (answer.status !== 200) return failed(answer);

    const { data, meta } = answer.data;

    await learnCommunities(data.map((p) => p.community_id));
    ctx.rememberPosts(data);

    ctx.store.set((state) => {
      const known = state.activity[id] ?? { ...NO_ACTIVITY };
      const ids = data.map((p) => p.id);

      const seen = new Set(known.posts);

      known.posts = after ? [...known.posts, ...ids.filter((i) => !seen.has(i))] : ids;
      known.postsAfter = meta.has_next ? meta.after : null;
      state.activity[id] = known;
    });

    return ok(undefined);
  };

  const loadReplies = async (handle: string, id: string, after: string | null) => {
    const answer = await call(() =>
      userReplies(handle, after ? { after, limit: PAGE } : { limit: PAGE }),
    );

    if (answer.status !== 200) return failed(answer);

    const { data, meta } = answer.data;

    await learnCommunities(data.map((r) => r.post.community_id));
    ctx.rememberMentions(data.map((r) => r.reply.body));

    ctx.store.set((state) => {
      const known = state.activity[id] ?? { ...NO_ACTIVITY };
      const replies = data.map(toAuthored);

      known.replies = after
        ? [...known.replies, ...replies.filter((r) => !known.replies.some((k) => k.id === r.id))]
        : replies;

      known.repliesAfter = meta.has_next ? meta.after : null;
      state.activity[id] = known;
    });

    return ok(undefined);
  };

  const load = {
    // A name with no account answers ok and leaves the store without them, which the screen shows as not found
    profile: async (handle: string) => {
      await ctx.sessionLoaded;

      const answer = await call(() => userShow(handle));

      if (answer.status === 404) return ok(undefined);
      if (answer.status !== 200) return failed(answer);

      ctx.store.set((state) => {
        const known = state.people[answer.data.id];

        // Keeps what only your own answer carries, such as your email and privacy
        state.people[answer.data.id] = {
          ...known,
          ...fromProfile(answer.data),
          private: known?.private ?? false,
        };
      });

      return ok(undefined);
    },

    activity: async (handle: string, tab: 'posts' | 'replies', more = false) => {
      await ctx.sessionLoaded;

      // The profile loads first so the person is known by now unless they don't exist
      const id = personIdByHandle(ctx.store.get(), handle);

      if (!id) return ok(undefined);

      const known = ctx.store.get().activity[id];
      const knownAfter = tab === 'posts' ? known?.postsAfter : known?.repliesAfter;
      const after = more ? knownAfter : null;

      if (more && !after) return ok(undefined);

      return tab === 'posts'
        ? loadPosts(handle, id, after ?? null)
        : loadReplies(handle, id, after ?? null);
    },

    // Matches join the community's roles so the picker knows they share it with you
    mentionable: async (cid: string, query: string) => {
      const id = ctx.communityIds.get(cid);

      if (!id) return ok(undefined);

      if (!ctx.store.get().roles.some((r) => r.c === cid)) await loadRoles(cid);

      const answer = await call(() => communityMemberIndex(id, { q: query, limit: 8 }));

      if (answer.status !== 200) return failed(answer);

      ctx.store.set((state) => {
        for (const { user, role_keys } of answer.data) {
          state.people[user.id] ??= toPerson(user);

          for (const role of state.roles)
            if (role.c === cid && role_keys.includes(role.id) && !role.members.includes(user.id))
              role.members.push(user.id);
        }
      });

      return ok(undefined);
    },
  } satisfies Partial<HearthGateway['load']>;

  const people = async () => {
    const answer = await call(() => peopleIndex({ limit: 100 }));

    if (answer.status !== 200) return failed(answer);

    ctx.store.set((state) => {
      for (const p of answer.data) {
        const seen = p.online ? 'online' : p.last_seen_at && ageOf(p.last_seen_at);

        const person = { ...(state.people[p.id] ?? toPerson(p)) };

        if (seen) person.lastSeen = seen;
        else delete person.lastSeen;

        state.people[p.id] = person;

        state.sharedCommunities[p.id] = p.community_ids.flatMap((id) => {
          const slug = ctx.communitySlugs.get(id);
          return slug ? [slug] : [];
        });
      }
    });

    return ok(undefined);
  };

  return { load: { ...load, people } };
}
